class_name SubjectPresenter
extends Node3D

var subject_anchor: Marker3D
var gate_camera: Camera3D
var door: Node3D
var door_open: Node3D
var side_window: Node3D
var peephole_view: SubViewportContainer
var peephole_viewport: SubViewport
var peephole_stage: PeepholeStage

var _subject_instance: Node3D
var _current_def: SubjectDef
var _move_tween: Tween
var _in_peephole: bool = false


func _ready() -> void:
	var parent := get_parent()
	subject_anchor = parent.get_node("world/subject_anchor") as Marker3D
	gate_camera = parent.get_node("Camera3D") as Camera3D
	door = parent.get_node("world/door") as Node3D
	door_open = parent.get_node("world/door_open") as Node3D
	side_window = parent.get_node("world/side_window") as Node3D
	peephole_view = parent.get_node("PeepholeLayer/PeepholeView") as SubViewportContainer
	if peephole_view:
		peephole_viewport = peephole_view.get_node("SubViewport") as SubViewport
		peephole_stage = peephole_viewport.get_node("PeepholeStage") as PeepholeStage
		peephole_view.visible = false
		peephole_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if door_open:
		door_open.visible = false
	if side_window:
		side_window.visible = false


func spawn_subject(subject: SubjectDef) -> void:
	clear_subject()
	_current_def = subject
	if subject == null or subject.subject_scene == null or subject_anchor == null:
		return
	_subject_instance = subject.subject_scene.instantiate() as Node3D
	subject_anchor.add_child(_subject_instance)
	if peephole_stage:
		peephole_stage.present(
			subject.subject_scene,
			subject.peephole_position,
			subject.peephole_rotation_degrees,
			subject.peephole_scale
		)


func apply_peephole_pose(
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float
) -> void:
	if _current_def:
		_current_def.peephole_position = pose_position
		_current_def.peephole_rotation_degrees = pose_rotation_degrees
		_current_def.peephole_scale = pose_scale
	if peephole_stage:
		peephole_stage.apply_pose(pose_position, pose_rotation_degrees, pose_scale)


func save_peephole_pose() -> String:
	if not OS.has_feature("editor"):
		return "Save only works when playing from the Godot editor."
	if _current_def == null or _current_def.resource_path.is_empty():
		return "No SubjectDef path to save."
	var err := ResourceSaver.save(_current_def, _current_def.resource_path)
	if err != OK:
		return "Save failed (%s)." % error_string(err)
	return "Saved %s" % _current_def.resource_path


func get_peephole_pose() -> Dictionary:
	if _current_def == null:
		return {
			"position": Vector3.ZERO,
			"rotation_degrees": Vector3.ZERO,
			"scale": 2.5,
		}
	return {
		"position": _current_def.peephole_position,
		"rotation_degrees": _current_def.peephole_rotation_degrees,
		"scale": _current_def.peephole_scale,
	}


func clear_subject() -> void:
	if _subject_instance and is_instance_valid(_subject_instance):
		_subject_instance.queue_free()
	_subject_instance = null
	_current_def = null
	if peephole_stage:
		peephole_stage.clear()


func enter_peephole() -> void:
	_in_peephole = true
	if peephole_viewport:
		peephole_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if peephole_view:
		peephole_view.visible = true


func exit_peephole() -> void:
	_in_peephole = false
	if peephole_view:
		peephole_view.visible = false
	if peephole_viewport:
		peephole_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if gate_camera:
		gate_camera.current = true


func is_in_peephole() -> bool:
	return _in_peephole


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
