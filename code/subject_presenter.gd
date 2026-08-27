class_name SubjectPresenter
extends Node3D

@export var door_fill := 0.9
@export var door_clearance := 2.0

var subject_anchor: Marker3D
var gate_camera: Camera3D
var door: Node3D
var door_top: Node3D
var door_open: Node3D
var side_window: Node3D
var outside_window_marker: Marker3D
var peephole_view: SubViewportContainer
var peephole_viewport: SubViewport
var peephole_stage: PeepholeStage

var _subject_instance: Node3D
var _current_def: SubjectDef
var _move_tween: Tween
var _in_peephole: bool = false
var _departing: Array[Node3D] = []
var _departing_tweens: Dictionary = {}


func _ready() -> void:
	var parent := get_parent()
	subject_anchor = parent.get_node("world/subject_anchor") as Marker3D
	gate_camera = parent.get_node("Camera3D") as Camera3D
	door = parent.get_node("world/door") as Node3D
	door_top = parent.get_node_or_null("world/door_top") as Node3D
	door_open = parent.get_node_or_null("world/door_open") as Node3D
	side_window = parent.get_node_or_null("world/side_window") as Node3D
	outside_window_marker = parent.get_node_or_null("world/outside_window_marker") as Marker3D
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
	var appearance := ModelCatalog.roll(subject.true_type)
	_subject_instance = subject.subject_scene.instantiate() as Node3D
	_subject_instance.visible = false
	subject_anchor.add_child(_subject_instance)
	if _subject_instance.has_method("apply_appearance"):
		_subject_instance.apply_appearance(appearance)
	call_deferred("_fit_subject_to_gate")
	if peephole_stage:
		peephole_stage.present(
			subject.subject_scene,
			subject.peephole_position,
			subject.peephole_rotation_degrees,
			subject.peephole_scale,
			appearance
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
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	if _subject_instance and is_instance_valid(_subject_instance):
		_subject_instance.queue_free()
	_subject_instance = null
	_current_def = null
	if peephole_stage:
		peephole_stage.clear()


func clear_all_subjects() -> void:
	clear_subject()
	_clear_departing()


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
	if door_open:
		door_open.visible = false
	if side_window and _departing.is_empty():
		side_window.visible = false


func play_accept(on_complete: Callable = Callable()) -> void:
	if door_open:
		door_open.visible = true
	if side_window:
		side_window.visible = false
	if _subject_instance and _subject_instance.has_method("play_walk"):
		_subject_instance.play_walk()
	_tween_subject(_door_offset_target(Vector3(0.0, 0.0, 5.0)), on_complete)


func play_reject(
	on_complete: Callable = Callable(),
	on_halfway: Callable = Callable()
) -> Node3D:
	if door_open:
		door_open.visible = false
	if side_window:
		side_window.visible = true
	var walker := _subject_instance
	_subject_instance = null
	if walker and walker.has_method("play_walk"):
		walker.play_walk()
	if walker == null or not is_instance_valid(walker):
		if on_halfway.is_valid():
			on_halfway.call()
		if on_complete.is_valid():
			on_complete.call()
		return null
	_departing.append(walker)
	if outside_window_marker == null:
		_tween_departing(
			walker,
			_door_offset_target(Vector3(-2.5, 0.0, 0.0)),
			2.2,
			on_complete,
			on_halfway
		)
		return walker
	var mid := outside_window_marker.global_position
	var start := mid + Vector3(0.0, 0.0, -6.0)
	var end := mid + Vector3(0.0, 0.0, 6.0)
	start.y = walker.global_position.y
	walker.global_position = start
	walker.look_at(start + Vector3(0.0, 0.0, 1.0), Vector3.UP, true)
	_tween_departing(
		walker,
		end,
		start.distance_to(end) * 2.2 / 5.0,
		on_complete,
		on_halfway
	)
	return walker


func _fit_subject_to_gate() -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		return
	var door_height := _door_world_height()
	if not GateFit.fit_stature(_subject_instance, door_height, door_fill):
		_subject_instance.visible = true
		return
	var aabb := GateFit.get_subject_aabb(_subject_instance)
	if door == null:
		_subject_instance.visible = true
		return
	var face := _subject_instance.find_child("Face", true, false) as Node3D
	var forward_extent := aabb.position.z + aabb.size.z
	if face:
		forward_extent = maxf(face.global_position.z, forward_extent)
	var max_allowed_z := door.global_position.z - door_clearance
	if forward_extent > max_allowed_z:
		_subject_instance.global_position.z -= forward_extent - max_allowed_z
	_subject_instance.visible = true


func _door_offset_target(offset: Vector3) -> Vector3:
	if door:
		return door.global_position + offset
	return offset


func _door_world_height() -> float:
	return GateFit.door_world_height(door, door_top)


func _get_subject_aabb(subject: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	for mesh in _find_mesh_instances(subject):
		var local_aabb := mesh.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue
		var global_aabb := mesh.global_transform * local_aabb
		if not has_bounds:
			merged = global_aabb
			has_bounds = true
		else:
			merged = merged.merge(global_aabb)
	return merged if has_bounds else AABB()


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		meshes.append_array(_find_mesh_instances(child))
	return meshes


func _tween_subject(target: Vector3, on_complete: Callable, duration: float = 2.2) -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		if on_complete.is_valid():
			on_complete.call()
		return
	if _move_tween:
		_move_tween.kill()
	target.y = _subject_instance.global_position.y
	_move_tween = create_tween()
	_move_tween.tween_property(_subject_instance, "global_position", target, duration)
	_move_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


func _tween_departing(
	walker: Node3D,
	target: Vector3,
	duration: float,
	on_complete: Callable,
	on_halfway: Callable
) -> void:
	target.y = walker.global_position.y
	var tween := create_tween()
	_departing_tweens[walker] = tween
	tween.set_parallel(true)
	tween.tween_property(walker, "global_position", target, duration)
	if on_halfway.is_valid():
		tween.tween_callback(on_halfway).set_delay(duration * 0.5)
	tween.set_parallel(false)
	tween.chain().tween_callback(func() -> void:
		_finish_departing(walker)
		if on_complete.is_valid():
			on_complete.call()
	)


func _finish_departing(walker: Node3D) -> void:
	_departing_tweens.erase(walker)
	_departing.erase(walker)
	if is_instance_valid(walker):
		walker.queue_free()
	if side_window and _departing.is_empty():
		side_window.visible = false


func _clear_departing() -> void:
	for tween in _departing_tweens.values():
		if tween is Tween:
			(tween as Tween).kill()
	_departing_tweens.clear()
	for walker in _departing:
		if is_instance_valid(walker):
			walker.queue_free()
	_departing.clear()
	if side_window:
		side_window.visible = false
