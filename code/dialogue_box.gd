class_name DialogueBox
extends Node3D

signal question_pressed(index: int)

const VIEWPORT_WIDTH := 440
const VIEWPORT_HEIGHT := 660
const PIXEL_SIZE := 0.005
const PANEL_WIDTH_M := 2.2
const PANEL_HEIGHT_M := 3.3
const PANEL_Z_OFFSET_M := 0.12
# Project forward is +Z (toward the player). Godot's Vector3.FORWARD is -Z.
const FORWARD := Vector3(0.0, 0.0, 1.0)
const TYPEWRITER_CHARS_PER_SEC := 40.0

const CARD_MARGIN := 12
const CARD_SEPARATION := 8
const CARD_CORNER_RADIUS := 16
const CARD_BORDER := 3
const FONT_SIZE := 32
const QUESTION_FONT := preload("res://fonts/AntipastoPro-DemiBold_trial.ttf")

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _viewport: SubViewport = $SubViewport
@onready var _body: StaticBody3D = $StaticBody3D
@onready var _reply_bubble: HBoxContainer = %ReplyBubble
@onready var _reply_panel: PanelContainer = %ReplyPanel
@onready var _reply_label: Label = %ReplyLabel
@onready var _speech_tail: SpeechBubbleTail = %SpeechBubbleTail
@onready var _question_buttons: VBoxContainer = %QuestionButtons

var _typewriter_tween: Tween
var _full_reply_text: String = ""
var _questions_enabled: bool = false
var _box_visible: bool = false
var _card_style: StyleBoxFlat
var _button_style_normal: StyleBoxFlat
var _button_style_hover: StyleBoxFlat
var _button_style_pressed: StyleBoxFlat
var _button_style_disabled: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_apply_panel_style(_reply_panel)
	_speech_tail.fill_color = _card_style.bg_color
	_speech_tail.border_color = _card_style.border_color
	_speech_tail.border_width = float(CARD_BORDER)
	_reply_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_reply_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_reply_panel.gui_input.connect(_on_reply_gui_input)
	_configure_world_display()
	hide_box()


func _unhandled_input(event: InputEvent) -> void:
	if not _box_visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		var hit := _raycast_at(mouse_event.position)
		if hit.is_empty() or hit.get("collider") != _body:
			return
		var local := to_local(hit.position)
		var vp_pos := _local_to_viewport(local)
		_push_viewport_mouse(mouse_event, vp_pos)
		get_viewport().set_input_as_handled()


func show_box() -> void:
	_box_visible = true
	_mesh.visible = true
	_body.input_ray_pickable = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func hide_box() -> void:
	_box_visible = false
	_mesh.visible = false
	_body.input_ray_pickable = false
	_stop_typewriter()
	_full_reply_text = ""
	_reply_label.text = ""
	_reply_label.visible_characters = -1
	_reply_bubble.visible = false


func set_questions(questions: Array[QuestionDef]) -> void:
	for child in _question_buttons.get_children():
		child.queue_free()
	for i in questions.size():
		var question := questions[i]
		var button := Button.new()
		button.text = question.button_label
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_button_styles(button)
		var index := i
		button.pressed.connect(func() -> void:
			_on_question_button_pressed(index)
		)
		_question_buttons.add_child(button)
	_apply_question_enabled_state()


func clear_reply() -> void:
	_stop_typewriter()
	_full_reply_text = ""
	_reply_label.text = ""
	_reply_label.visible_characters = -1
	_reply_bubble.visible = false


func set_reply(text: String) -> void:
	_stop_typewriter()
	_full_reply_text = text
	if text.is_empty():
		clear_reply()
		return
	_reply_bubble.visible = true
	_reply_label.text = text
	_reply_label.visible_characters = 0
	var char_count := text.length()
	var duration := char_count / TYPEWRITER_CHARS_PER_SEC
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_method(
		func(count: float) -> void:
			_reply_label.visible_characters = int(count),
		0.0,
		float(char_count),
		duration
	)
	_typewriter_tween.finished.connect(func() -> void:
		_reply_label.visible_characters = -1
	)


func set_questions_enabled(enabled: bool) -> void:
	_questions_enabled = enabled
	_apply_question_enabled_state()


func skip_typewriter() -> void:
	if _full_reply_text.is_empty():
		return
	_stop_typewriter()
	_reply_label.visible_characters = -1


func _on_question_button_pressed(index: int) -> void:
	if not _questions_enabled:
		return
	skip_typewriter()
	question_pressed.emit(index)


func _on_reply_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			skip_typewriter()


func _apply_question_enabled_state() -> void:
	for child in _question_buttons.get_children():
		if child is Button:
			child.disabled = not _questions_enabled


func _configure_world_display() -> void:
	_viewport.size = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var quad := QuadMesh.new()
	quad.size = Vector2(PANEL_WIDTH_M, PANEL_HEIGHT_M)
	quad.orientation = PlaneMesh.FACE_Z
	_mesh.mesh = quad
	# Origin is the top-left of the panel. It extends +X (right), -Y (down),
	# and sits slightly along +Z so the readable face points forward.
	_mesh.basis = Basis(Vector3.RIGHT, Vector3.UP, FORWARD)
	_mesh.position = _panel_center_local()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mesh.material_override = mat

	var shape := _body.get_node("CollisionShape3D").shape as BoxShape3D
	if shape != null:
		shape.size = Vector3(PANEL_WIDTH_M, PANEL_HEIGHT_M, 0.02)
	var collision := _body.get_node("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.basis = _mesh.basis
		collision.position = _panel_center_local()


func _build_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color.WHITE
	_card_style.border_color = Color.BLACK
	_card_style.set_border_width_all(CARD_BORDER)
	_card_style.set_corner_radius_all(CARD_CORNER_RADIUS)
	_card_style.set_content_margin_all(CARD_MARGIN)

	_button_style_normal = _card_style.duplicate() as StyleBoxFlat
	_button_style_hover = _card_style.duplicate() as StyleBoxFlat
	_button_style_hover.bg_color = Color(0.92, 0.92, 0.92, 1.0)
	_button_style_pressed = _card_style.duplicate() as StyleBoxFlat
	_button_style_pressed.bg_color = Color(0.85, 0.85, 0.85, 1.0)
	_button_style_disabled = _card_style.duplicate() as StyleBoxFlat
	_button_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1.0)
	_button_style_disabled.border_color = Color(0.45, 0.45, 0.45, 1.0)


func _apply_panel_style(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _card_style)


func _apply_button_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hover)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("disabled", _button_style_disabled)
	button.add_theme_stylebox_override("focus", _button_style_normal)
	button.add_theme_font_override("font", QUESTION_FONT)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45, 1.0))


func _stop_typewriter() -> void:
	if _typewriter_tween != null:
		_typewriter_tween.kill()
		_typewriter_tween = null


func _raycast_at(screen_pos: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _panel_center_local() -> Vector3:
	return Vector3(PANEL_WIDTH_M * 0.5, -PANEL_HEIGHT_M * 0.5, 0.0) + FORWARD * PANEL_Z_OFFSET_M


func _local_to_viewport(local: Vector3) -> Vector2:
	# Hit point is in this node's space: +X right, -Y down, +Z forward.
	var px := clampi(int(local.x / PIXEL_SIZE), 0, VIEWPORT_WIDTH - 1)
	var py := clampi(int(-local.y / PIXEL_SIZE), 0, VIEWPORT_HEIGHT - 1)
	return Vector2(px, py)


func _push_viewport_mouse(source: InputEventMouseButton, vp_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = source.button_index
	press.pressed = true
	press.position = vp_pos
	press.global_position = vp_pos
	_viewport.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = source.button_index
	release.pressed = false
	release.position = vp_pos
	release.global_position = vp_pos
	_viewport.push_input(release)
