class_name PlayerCamera
extends Camera3D

@export_group("Mouse Look")
@export var mouse_look_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var mouse_look_sensitivity: float = 1.0
@export_range(0.0, 15.0, 0.1) var mouse_look_max_yaw_degrees: float = 4.0
@export_range(0.0, 15.0, 0.1) var mouse_look_max_pitch_degrees: float = 3.0
@export_range(0.5, 20.0, 0.1) var mouse_look_smoothing: float = 6.0

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

@export_group("Reject Look")
@export_range(0.0, 8.0, 0.01) var reject_look_delay: float = 2.0
@export_range(0.1, 4.0, 0.01) var reject_look_ease_in: float = 0.65
@export_range(0.5, 12.0, 0.01) var reject_look_blend: float = 3.0
@export var reject_look_height: float = 1.6

var _time: float = 0.0
var _mouse_look_current: Vector2 = Vector2.ZERO
var _rest_transform: Transform3D
var _bobbing: bool = true
var _move_tween: Tween
var _reject_delay_tween: Tween
var _tracking_subject: Node3D
var _tracking_active: bool = false
var _follow_weight: float = 0.0
var _lagged_look: Vector3 = Vector3.ZERO
var _rest_return_callback: Callable


func _ready() -> void:
	capture_rest()


func capture_rest() -> void:
	_rest_transform = transform
	_bobbing = true
	if peephole_marker == null:
		peephole_marker = get_node_or_null("../world/door_hotspot_peephole") as Marker3D


func _process(delta: float) -> void:
	if _tracking_active:
		_process_reject_follow(delta)
		return
	if not _bobbing or not bob_enabled:
		return
	_time += delta * idle_speed
	var bob_y := sin(_time) * idle_amount
	var bob_x := cos(_time * 0.5) * idle_amount * idle_horizontal_ratio
	var pitch := deg_to_rad(sin(_time) * bob_pitch_degrees)
	var roll := deg_to_rad(cos(_time * 0.5) * bob_roll_degrees)
	var target_look := _mouse_look_target()
	var catch_up := 1.0 - exp(-mouse_look_smoothing * delta)
	_mouse_look_current = _mouse_look_current.lerp(target_look, catch_up)
	var rest_euler := _rest_transform.basis.get_euler()
	position = _rest_transform.origin + Vector3(bob_x, bob_y, 0.0)
	rotation = rest_euler + Vector3(pitch + _mouse_look_current.y, _mouse_look_current.x, roll)


func move_to_peephole() -> void:
	var target_origin := _peephole_origin()
	_tween_camera(target_origin, _peephole_basis(target_origin), false)


func return_to_rest(on_complete: Callable = Callable()) -> void:
	_stop_reject_tracking()
	var rest_global := _rest_global_transform()
	_tween_camera(rest_global.origin, rest_global.basis, true, on_complete)


func snap_to_rest() -> void:
	_cancel_reject_follow()
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	transform = _rest_transform
	_mouse_look_current = Vector2.ZERO
	_bobbing = true


func begin_reject_follow(subject: Node3D) -> void:
	_cancel_reject_follow()
	if subject == null or not is_instance_valid(subject):
		return
	_tracking_subject = subject
	_reject_delay_tween = create_tween()
	_reject_delay_tween.tween_interval(reject_look_delay)
	_reject_delay_tween.tween_callback(_start_reject_tracking)


func end_reject_follow(on_complete: Callable = Callable()) -> void:
	_kill_reject_delay()
	_tracking_active = false
	_tracking_subject = null
	_follow_weight = 0.0
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	var rest_global := _rest_global_transform()
	_tween_camera(rest_global.origin, rest_global.basis, true, on_complete)


func _cancel_reject_follow() -> void:
	_kill_reject_delay()
	_tracking_active = false
	_tracking_subject = null
	_follow_weight = 0.0
	_rest_return_callback = Callable()


func _kill_reject_delay() -> void:
	if _reject_delay_tween:
		_reject_delay_tween.kill()
		_reject_delay_tween = null


func _start_reject_tracking() -> void:
	_reject_delay_tween = null
	if _tracking_subject == null or not is_instance_valid(_tracking_subject):
		return
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	_bobbing = false
	transform = _rest_transform
	_follow_weight = 0.0
	_lagged_look = _reject_look_point(_tracking_subject)
	_tracking_active = true


func _stop_reject_tracking() -> void:
	_kill_reject_delay()
	_tracking_active = false
	_tracking_subject = null
	_follow_weight = 0.0


func _process_reject_follow(delta: float) -> void:
	if _tracking_subject == null or not is_instance_valid(_tracking_subject):
		_tracking_active = false
		return
	var rest_global := _rest_global_transform()
	global_position = rest_global.origin
	_lagged_look = _lagged_look.lerp(
		_reject_look_point(_tracking_subject),
		1.0 - exp(-reject_look_blend * delta)
	)
	if global_position.distance_squared_to(_lagged_look) < 0.0001:
		return
	var ease_in := maxf(reject_look_ease_in, 0.05)
	_follow_weight = move_toward(_follow_weight, 1.0, delta / ease_in)
	look_at(_lagged_look, Vector3.UP)
	if _follow_weight < 1.0:
		global_transform.basis = rest_global.basis.slerp(global_transform.basis, _follow_weight)


func _reject_look_point(subject: Node3D) -> Vector3:
	var face := subject.find_child("Face", true, false) as Node3D
	if face:
		return face.global_position
	var aabb := _subject_visual_aabb(subject)
	if aabb.size != Vector3.ZERO:
		return aabb.get_center()
	var look := subject.global_position
	look.y += reject_look_height
	return look


func _subject_visual_aabb(subject: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	var stack: Array[Node] = [subject]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var local_aabb := mesh.get_aabb()
			if local_aabb.size != Vector3.ZERO:
				var global_aabb := mesh.global_transform * local_aabb
				if not has_bounds:
					merged = global_aabb
					has_bounds = true
				else:
					merged = merged.merge(global_aabb)
		for child in node.get_children():
			stack.append(child)
	return merged if has_bounds else AABB()


func _can_mouse_look() -> bool:
	return mouse_look_enabled and _bobbing and not _tracking_active


func _mouse_look_target() -> Vector2:
	if not _can_mouse_look():
		return Vector2.ZERO
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var rect := viewport.get_visible_rect()
	var center := rect.size * 0.5
	var offset := viewport.get_mouse_position() - center
	var normalized := Vector2(
		offset.x / maxf(center.x, 1.0),
		offset.y / maxf(center.y, 1.0)
	).clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0)) * mouse_look_sensitivity
	return Vector2(
		-normalized.x * deg_to_rad(mouse_look_max_yaw_degrees),
		-normalized.y * deg_to_rad(mouse_look_max_pitch_degrees)
	)


func _tween_camera(
	target_origin: Vector3,
	target_basis: Basis,
	resume_bob: bool,
	on_complete: Callable = Callable()
) -> void:
	_bobbing = false
	_mouse_look_current = Vector2.ZERO
	if _move_tween:
		_move_tween.kill()
	var start_origin := global_position
	var start_basis := global_transform.basis
	_rest_return_callback = on_complete
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
		var callback := _rest_return_callback
		_rest_return_callback = Callable()
		if callback.is_valid():
			callback.call()
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
