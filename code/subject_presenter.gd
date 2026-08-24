class_name SubjectPresenter
extends Node3D

var subject_anchor: Marker3D
var gate_camera: Camera3D
var peephole_camera: Camera3D
var door: Node3D
var door_open: Node3D
var side_window: Node3D

var _subject_instance: Node3D
var _gate_camera_rest_transform: Transform3D
var _zoom_tween: Tween
var _move_tween: Tween


func _ready() -> void:
	var parent := get_parent()
	subject_anchor = parent.get_node("world/subject_anchor") as Marker3D
	gate_camera = parent.get_node("Camera3D") as Camera3D
	peephole_camera = parent.get_node("PeepholeCamera3D") as Camera3D
	door = parent.get_node("world/door") as Node3D
	door_open = parent.get_node("world/door_open") as Node3D
	side_window = parent.get_node("world/side_window") as Node3D
	if gate_camera:
		_gate_camera_rest_transform = gate_camera.transform
	_aim_peephole_at_face()
	if door_open:
		door_open.visible = false
	if side_window:
		side_window.visible = false


func spawn_subject(subject_scene: PackedScene) -> void:
	clear_subject()
	if subject_scene == null or subject_anchor == null:
		return
	_subject_instance = subject_scene.instantiate() as Node3D
	subject_anchor.add_child(_subject_instance)
	_aim_peephole_at_face()


func clear_subject() -> void:
	if _subject_instance and is_instance_valid(_subject_instance):
		_subject_instance.queue_free()
	_subject_instance = null


func enter_peephole(on_complete: Callable = Callable()) -> void:
	if gate_camera == null or peephole_camera == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	if _zoom_tween:
		_zoom_tween.kill()
	var zoom_target := gate_camera.global_transform
	zoom_target.origin = zoom_target.origin.lerp(
		Vector3(0.0, 1.45, 0.55),
		0.65
	)
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(gate_camera, "global_transform", zoom_target, 0.35)
	_aim_peephole_at_face()
	_zoom_tween.tween_callback(func() -> void:
		peephole_camera.current = true
		if on_complete.is_valid():
			on_complete.call()
	)


func exit_peephole() -> void:
	if peephole_camera:
		peephole_camera.current = false
	if gate_camera:
		gate_camera.current = true
		if _zoom_tween:
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(gate_camera, "transform", _gate_camera_rest_transform, 0.35)


func set_door_closed() -> void:
	if door:
		door.visible = true
	if door_open:
		door_open.visible = false
	if side_window:
		side_window.visible = false


func play_accept(on_complete: Callable = Callable()) -> void:
	if door:
		door.visible = false
	if door_open:
		door_open.visible = true
	if side_window:
		side_window.visible = false
	_tween_subject(Vector3(0.0, 0.0, 1.5), on_complete)


func play_reject(on_complete: Callable = Callable()) -> void:
	if door:
		door.visible = true
	if door_open:
		door_open.visible = false
	if side_window:
		side_window.visible = true
	_tween_subject(Vector3(1.4, 0.0, 0.2), on_complete)


func _aim_peephole_at_face() -> void:
	if peephole_camera == null:
		return
	var target := _face_global_position()
	if peephole_camera.global_position.is_equal_approx(target):
		return
	peephole_camera.look_at(target, Vector3.UP)


func _face_global_position() -> Vector3:
	if _subject_instance and is_instance_valid(_subject_instance):
		var face := _subject_instance.find_child("Face", true, false) as Node3D
		if face:
			return face.global_position
	if subject_anchor:
		return subject_anchor.global_position + Vector3(0.0, 1.45, 0.0)
	return Vector3.ZERO


func _tween_subject(target: Vector3, on_complete: Callable) -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		if on_complete.is_valid():
			on_complete.call()
		return
	if _move_tween:
		_move_tween.kill()
	target.y = _subject_instance.global_position.y
	_move_tween = create_tween()
	_move_tween.tween_property(_subject_instance, "global_position", target, 1.2)
	_move_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)
