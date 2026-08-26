extends Camera3D

@export var move_speed := 6.0
@export var vertical_speed := 4.0
@export var mouse_sensitivity := 0.002

var _pitch := 0.0
var _yaw := 0.0


func _ready() -> void:
	_pitch = rotation.x
	_yaw = rotation.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var horizontal := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		horizontal -= transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		horizontal += transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += transform.basis.x
	horizontal.y = 0.0
	if horizontal.length_squared() > 0.0:
		position += horizontal.normalized() * move_speed * delta

	var vertical := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		vertical -= 1.0
	if vertical != 0.0:
		position.y += vertical * vertical_speed * delta
