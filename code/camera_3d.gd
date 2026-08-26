class_name PlayerCamera
extends Camera3D

@export_group("Idle Bob")
@export var bob_enabled: bool = true
@export_range(0.0, 8.0, 0.01) var idle_speed: float = 1.0
@export_range(0.0, 0.5, 0.001) var idle_amount: float = 0.05
@export_range(0.0, 2.0, 0.01) var idle_horizontal_ratio: float = 0.5
@export_range(0.0, 5.0, 0.01) var bob_pitch_degrees: float = 0.2
@export_range(0.0, 5.0, 0.01) var bob_roll_degrees: float = 0.12

@export_group("Peephole Transition")
@export var peephole_marker: Marker3D
@export var peephole_stand_offset := Vector3(0.0, 0.0, 0.45)
@export_range(0.05, 3.0, 0.01) var peephole_move_duration: float = 0.75
@export var look_at_peephole: bool = true

var _time: float = 0.0
var _rest_transform: Transform3D
var _bobbing: bool = true
var _move_tween: Tween


func _ready() -> void:
	capture_rest()


func capture_rest() -> void:
	_rest_transform = transform
	_bobbing = true
	if peephole_marker == null:
		peephole_marker = get_node_or_null("../world/door_hotspot_peephole") as Marker3D


func _process(delta: float) -> void:
	if not _bobbing or not bob_enabled:
		return
	_time += delta * idle_speed
	var bob_y := sin(_time) * idle_amount
	var bob_x := cos(_time * 0.5) * idle_amount * idle_horizontal_ratio
	var pitch := deg_to_rad(sin(_time) * bob_pitch_degrees)
	var roll := deg_to_rad(cos(_time * 0.5) * bob_roll_degrees)
	var rest_euler := _rest_transform.basis.get_euler()
	position = _rest_transform.origin + Vector3(bob_x, bob_y, 0.0)
	rotation = rest_euler + Vector3(pitch, 0.0, roll)


func move_to_peephole() -> void:
	var target_origin := _peephole_origin()
	_tween_camera(target_origin, _peephole_basis(target_origin), false)


func return_to_rest() -> void:
	var rest_global := _rest_global_transform()
	_tween_camera(rest_global.origin, rest_global.basis, true)


func snap_to_rest() -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	transform = _rest_transform
	_bobbing = true


func _tween_camera(target_origin: Vector3, target_basis: Basis, resume_bob: bool) -> void:
	_bobbing = false
	if _move_tween:
		_move_tween.kill()
	var start_origin := global_position
	var start_basis := global_transform.basis
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_method(
		func(weight: float) -> void:
			global_transform = Transform3D(
				start_basis.slerp(target_basis, weight),
				start_origin.lerp(target_origin, weight)
			),
		0.0,
		1.0,
		peephole_move_duration
	)
	_move_tween.tween_callback(func() -> void:
		_move_tween = null
		if resume_bob:
			transform = _rest_transform
			_bobbing = true
	)


func _rest_global_transform() -> Transform3D:
	var parent_3d := get_parent() as Node3D
	if parent_3d:
		return parent_3d.global_transform * _rest_transform
	return _rest_transform


func _peephole_origin() -> Vector3:
	if peephole_marker == null:
		return global_position
	return peephole_marker.global_position + peephole_stand_offset


func _peephole_basis(origin: Vector3) -> Basis:
	if not look_at_peephole or peephole_marker == null:
		return _rest_transform.basis
	var look_target := peephole_marker.global_position
	if origin.distance_squared_to(look_target) < 0.0001:
		return _rest_transform.basis
	return Basis.looking_at(look_target - origin, Vector3.UP)
