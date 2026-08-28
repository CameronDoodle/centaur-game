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

@export_group("Wrong Accept Penalty")
@export_range(-5.0, 5.0, 0.05) var wrong_accept_push_delay_offset: float = 0.0
@export_range(0.0, 8.0, 0.01) var wrong_accept_knock_distance: float = 2.2
@export_range(0.05, 2.0, 0.01) var wrong_accept_knock_duration: float = 0.12
@export_range(0.0, 3.0, 0.01) var wrong_accept_track_delay: float = 0.0
@export_range(0.1, 4.0, 0.01) var wrong_accept_track_ease_in: float = 0.35
@export_range(0.5, 12.0, 0.01) var wrong_accept_track_blend: float = 6.0
@export_range(0.1, 12.0, 0.05) var wrong_accept_track_duration: float = 2.0
@export_range(0.1, 3.0, 0.01) var wrong_accept_return_duration: float = 0.75

@export_group("Idle Resume")
@export_range(0.1, 2.0, 0.01) var idle_resume_duration: float = 0.35

@export_group("Title Transition")
@export_range(0.5, 6.0, 0.1) var title_fly_duration: float = 2.5

var _time: float = 0.0
var _mouse_look_current: Vector2 = Vector2.ZERO
var _rest_transform: Transform3D
var _bobbing: bool = true
var _idle_blend: float = 1.0
var _move_tween: Tween
var _reject_delay_tween: Tween
var _idle_blend_tween: Tween
var _tracking_subject: Node3D
var _tracking_active: bool = false
var _follow_weight: float = 0.0
var _lagged_look: Vector3 = Vector3.ZERO
var _rest_return_callback: Callable
var _knock_offset: Vector3 = Vector3.ZERO
var _knock_tween: Tween
var _wrong_accept_penalty: bool = false
var _penalty_returning: bool = false
var _penalty_return_tween: Tween
var _penalty_sequence_tween: Tween
var _penalty_sequence_on_complete: Callable
var _tracked_yaw: float = 0.0


func _ready() -> void:
	capture_rest()


func capture_rest() -> void:
	_rest_transform = transform
	_bobbing = true
	if peephole_marker == null:
		peephole_marker = get_node_or_null("../world/door_hotspot_peephole") as Marker3D


func _process(delta: float) -> void:
	if not _bobbing and not _wrong_accept_penalty:
		return
	var blend := _idle_blend
	var bob_y := 0.0
	var bob_x := 0.0
	var pitch := 0.0
	var roll := 0.0
	if _bobbing and bob_enabled:
		_time += delta * idle_speed
		bob_y = sin(_time) * idle_amount * blend
		bob_x = cos(_time * 0.5) * idle_amount * idle_horizontal_ratio * blend
		pitch = deg_to_rad(sin(_time) * bob_pitch_degrees) * blend
		roll = deg_to_rad(cos(_time * 0.5) * bob_roll_degrees) * blend
	var target_look := _mouse_look_target() * blend
	var catch_up := 1.0 - exp(-mouse_look_smoothing * delta)
	_mouse_look_current = _mouse_look_current.lerp(target_look, catch_up)
	var rest_euler := _rest_transform.basis.get_euler()
	position = _rest_transform.origin + Vector3(bob_x, bob_y, 0.0) + _knock_offset
	var bob_rotation := Vector3(pitch, 0.0, roll)
	if _wrong_accept_penalty:
		_apply_wrong_accept_tracking(delta, rest_euler, bob_rotation)
	elif _tracking_active:
		rotation = rest_euler + bob_rotation + Vector3(_mouse_look_current.y, _mouse_look_current.x, 0.0)
		_apply_reject_tracking(delta)
	else:
		rotation = rest_euler + bob_rotation + Vector3(_mouse_look_current.y, _mouse_look_current.x, 0.0)


func move_to_peephole() -> void:
	var target_origin := _peephole_origin()
	_tween_camera(target_origin, _peephole_basis(target_origin), false)


func return_to_rest(on_complete: Callable = Callable()) -> void:
	_stop_reject_tracking()
	var rest_global := _rest_global_transform()
	_tween_camera(rest_global.origin, rest_global.basis, true, on_complete)


func snap_to_rest() -> void:
	_cancel_reject_follow()
	_cancel_wrong_accept_penalty()
	_kill_idle_blend_tween()
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	transform = _rest_transform
	_mouse_look_current = Vector2.ZERO
	_idle_blend = 1.0
	_bobbing = true


func hold_at_marker(marker: Marker3D) -> void:
	if marker == null:
		return
	_cancel_reject_follow()
	_cancel_wrong_accept_penalty()
	_kill_idle_blend_tween()
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	_bobbing = false
	_idle_blend = 0.0
	_mouse_look_current = Vector2.ZERO
	global_transform = marker.global_transform


func fly_to_rest(duration: float = -1.0, on_complete: Callable = Callable()) -> void:
	var rest_global := _rest_global_transform()
	var fly_duration := duration if duration > 0.0 else title_fly_duration
	_tween_camera(rest_global.origin, rest_global.basis, true, on_complete, fly_duration)


static func window_look_rest(rest: Transform3D) -> Transform3D:
	var yawed_basis := rest.basis.rotated(Vector3.UP, deg_to_rad(90.0))
	return Transform3D(yawed_basis, rest.origin)


func look_out_window() -> void:
	_cancel_reject_follow()
	_cancel_wrong_accept_penalty()
	_rest_transform = window_look_rest(_rest_transform)
	var window_global := _rest_global_transform()
	_tween_camera(
		window_global.origin,
		window_global.basis,
		true,
		Callable(),
		title_fly_duration
	)


func begin_reject_follow(subject: Node3D) -> void:
	_cancel_reject_follow()
	if subject == null or not is_instance_valid(subject):
		return
	_kill_idle_blend_tween()
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


func play_wrong_accept_sequence(
	subject: Node3D,
	knock_delay: float,
	on_complete: Callable = Callable()
) -> void:
	_cancel_wrong_accept_penalty()
	if subject == null or not is_instance_valid(subject):
		_penalty_sequence_on_complete = Callable()
		if on_complete.is_valid():
			on_complete.call()
		return
	_penalty_sequence_on_complete = on_complete
	_wrong_accept_penalty = true
	_penalty_returning = false
	_tracking_subject = subject
	_tracking_active = false
	_follow_weight = 0.0
	_tracked_yaw = _rest_transform.basis.get_euler().y
	_knock_offset = Vector3.ZERO
	var knock_dir := Vector3(_rest_transform.basis.x.x, 0.0, _rest_transform.basis.x.z)
	if knock_dir.length_squared() < 0.0001:
		knock_dir = Vector3.RIGHT
	knock_dir = knock_dir.normalized()
	var push_delay := maxf(0.0, knock_delay + wrong_accept_push_delay_offset)
	_penalty_sequence_tween = create_tween()
	if push_delay > 0.0:
		_penalty_sequence_tween.tween_interval(push_delay)
	_penalty_sequence_tween.set_trans(Tween.TRANS_QUAD)
	_penalty_sequence_tween.set_ease(Tween.EASE_OUT)
	_penalty_sequence_tween.tween_method(
		func(weight: float) -> void:
			_knock_offset = knock_dir * wrong_accept_knock_distance * weight,
		0.0,
		1.0,
		wrong_accept_knock_duration
	)
	if wrong_accept_track_delay > 0.0:
		_penalty_sequence_tween.tween_interval(wrong_accept_track_delay)
	_penalty_sequence_tween.tween_callback(func() -> void:
		_tracking_active = true
	)
	_penalty_sequence_tween.tween_interval(wrong_accept_track_duration)
	_penalty_sequence_tween.tween_callback(func() -> void:
		_penalty_sequence_tween = null
		end_wrong_accept_penalty()
	)


func begin_wrong_accept_penalty(subject: Node3D) -> void:
	_cancel_wrong_accept_penalty()
	if subject == null or not is_instance_valid(subject):
		return
	_wrong_accept_penalty = true
	_penalty_returning = false
	_tracking_subject = subject
	_tracking_active = true
	_follow_weight = 0.0
	_tracked_yaw = _rest_transform.basis.get_euler().y
	if _knock_tween:
		_knock_tween.kill()
		_knock_tween = null
	var knock_dir := Vector3(_rest_transform.basis.x.x, 0.0, _rest_transform.basis.x.z)
	if knock_dir.length_squared() < 0.0001:
		knock_dir = Vector3.RIGHT
	knock_dir = knock_dir.normalized()
	_knock_offset = Vector3.ZERO
	_knock_tween = create_tween()
	_knock_tween.set_trans(Tween.TRANS_QUAD)
	_knock_tween.set_ease(Tween.EASE_OUT)
	_knock_tween.tween_method(
		func(weight: float) -> void:
			_knock_offset = knock_dir * wrong_accept_knock_distance * weight,
		0.0,
		1.0,
		wrong_accept_knock_duration
	)


func end_wrong_accept_penalty(on_complete: Callable = Callable()) -> void:
	var complete := on_complete if on_complete.is_valid() else _penalty_sequence_on_complete
	if _knock_tween:
		_knock_tween.kill()
		_knock_tween = null
	if _penalty_return_tween:
		_penalty_return_tween.kill()
		_penalty_return_tween = null
	_penalty_returning = true
	var start_knock := _knock_offset
	var start_weight := _follow_weight
	_penalty_return_tween = create_tween()
	_penalty_return_tween.set_trans(Tween.TRANS_SINE)
	_penalty_return_tween.set_ease(Tween.EASE_IN_OUT)
	_penalty_return_tween.set_parallel(true)
	_penalty_return_tween.tween_method(
		func(weight: float) -> void:
			_knock_offset = start_knock * (1.0 - weight)
			_follow_weight = start_weight * (1.0 - weight),
		0.0,
		1.0,
		wrong_accept_return_duration
	)
	_penalty_return_tween.set_parallel(false)
	_penalty_return_tween.tween_callback(func() -> void:
		_penalty_return_tween = null
		_complete_wrong_accept_penalty(complete)
	)


func _complete_wrong_accept_penalty(on_complete: Callable) -> void:
	_penalty_sequence_on_complete = Callable()
	_cancel_wrong_accept_penalty()
	if on_complete.is_valid():
		on_complete.call()


func _cancel_reject_follow() -> void:
	_kill_reject_delay()
	if not _wrong_accept_penalty:
		_tracking_active = false
		_tracking_subject = null
		_follow_weight = 0.0
	_rest_return_callback = Callable()


func _cancel_wrong_accept_penalty() -> void:
	if _penalty_sequence_tween:
		_penalty_sequence_tween.kill()
		_penalty_sequence_tween = null
	if _knock_tween:
		_knock_tween.kill()
		_knock_tween = null
	if _penalty_return_tween:
		_penalty_return_tween.kill()
		_penalty_return_tween = null
	_knock_offset = Vector3.ZERO
	_wrong_accept_penalty = false
	_penalty_returning = false
	_tracking_active = false
	_tracking_subject = null
	_follow_weight = 0.0
	_tracked_yaw = 0.0
	_penalty_sequence_on_complete = Callable()


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
	_follow_weight = 0.0
	_lagged_look = _reject_look_point(_tracking_subject)
	_tracking_active = true


func _stop_reject_tracking() -> void:
	_kill_reject_delay()
	_tracking_active = false
	_tracking_subject = null
	_follow_weight = 0.0


func _apply_reject_tracking(delta: float) -> void:
	if _tracking_subject == null or not is_instance_valid(_tracking_subject):
		_tracking_active = false
		return
	var ease_in := maxf(reject_look_ease_in, 0.05)
	_follow_weight = move_toward(_follow_weight, 1.0, delta / ease_in)
	_lagged_look = _lagged_look.lerp(
		_reject_look_point(_tracking_subject),
		1.0 - exp(-reject_look_blend * delta)
	)
	if global_position.distance_squared_to(_lagged_look) < 0.0001:
		return
	var base_basis := global_transform.basis
	look_at(_lagged_look, Vector3.UP)
	var track_basis := global_transform.basis
	global_transform.basis = base_basis.slerp(track_basis, _follow_weight)


func _apply_wrong_accept_tracking(delta: float, rest_euler: Vector3, bob_rotation: Vector3) -> void:
	if _tracking_subject == null or not is_instance_valid(_tracking_subject):
		_tracking_active = false
		rotation = rest_euler + bob_rotation + Vector3(_mouse_look_current.y, _mouse_look_current.x, 0.0)
		return
	if not _penalty_returning and _tracking_active:
		var ease_in := maxf(wrong_accept_track_ease_in, 0.05)
		_follow_weight = move_toward(_follow_weight, 1.0, delta / ease_in)
	var desired_yaw := _tracked_yaw
	if _tracking_active:
		desired_yaw = _penalty_yaw_to_subject(_tracking_subject)
		var track_catch_up := 1.0 - exp(-wrong_accept_track_blend * delta)
		_tracked_yaw = lerp_angle(_tracked_yaw, desired_yaw, track_catch_up)
	var yaw := lerp_angle(rest_euler.y, _tracked_yaw, _follow_weight)
	rotation = Vector3(
		rest_euler.x + bob_rotation.x + _mouse_look_current.y,
		yaw + _mouse_look_current.x,
		rest_euler.z + bob_rotation.z
	)


func _penalty_yaw_to_subject(subject: Node3D) -> float:
	var look := subject.global_position
	look.y = global_position.y
	var offset := look - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.04:
		return _tracked_yaw
	var look_basis := Basis.looking_at(offset, Vector3.UP)
	return look_basis.get_euler().y


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
	return mouse_look_enabled and _bobbing


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
	on_complete: Callable = Callable(),
	duration: float = -1.0
) -> void:
	_bobbing = false
	_kill_idle_blend_tween()
	_idle_blend = 0.0
	_mouse_look_current = Vector2.ZERO
	if _move_tween:
		_move_tween.kill()
	var start_origin := global_position
	var start_basis := global_transform.basis
	var move_duration := duration if duration > 0.0 else peephole_move_duration
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
		move_duration
	)
	_move_tween.tween_callback(func() -> void:
		_move_tween = null
		if resume_bob:
			_bobbing = true
			_begin_idle_blend()
		var callback := _rest_return_callback
		_rest_return_callback = Callable()
		if callback.is_valid():
			callback.call()
	)


func _begin_idle_blend() -> void:
	_time = 0.0
	_idle_blend = 0.0
	_mouse_look_current = Vector2.ZERO
	_kill_idle_blend_tween()
	_idle_blend_tween = create_tween()
	_idle_blend_tween.set_trans(Tween.TRANS_SINE)
	_idle_blend_tween.set_ease(Tween.EASE_IN_OUT)
	_idle_blend_tween.tween_property(self, "_idle_blend", 1.0, idle_resume_duration)
	_idle_blend_tween.tween_callback(func() -> void:
		_idle_blend_tween = null
		_idle_blend = 1.0
	)


func _kill_idle_blend_tween() -> void:
	if _idle_blend_tween:
		_idle_blend_tween.kill()
		_idle_blend_tween = null


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
