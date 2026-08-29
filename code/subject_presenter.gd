class_name SubjectPresenter
extends Node3D

const WALK_SPEED := 4.0
const WALK_PAST_DISTANCE := 6.0
const WINDOW_WALK_DISTANCE := 12.0
const ACCEPT_START_HANDLE := 0.7
const ACCEPT_DOOR_CLOSE_DELAY := 1.0

@export var door_fill := 0.9
@export var door_clearance := 2.0

@export_group("Walk")
@export_range(0.5, 12.0, 0.05) var walk_speed: float = WALK_SPEED
@export_range(1.0, 40.0, 0.1) var window_walk_distance: float = WINDOW_WALK_DISTANCE
@export_range(1.0, 20.0, 0.1) var walk_past_distance: float = WALK_PAST_DISTANCE
@export_range(0.05, 2.0, 0.01) var accept_start_handle: float = ACCEPT_START_HANDLE
@export_range(0.0, 5.0, 0.05) var accept_door_close_delay: float = ACCEPT_DOOR_CLOSE_DELAY

@export_group("Wrong Accept")
@export_range(1.0, 40.0, 0.1) var penalty_walk_distance: float = WINDOW_WALK_DISTANCE

@export var subject_catalog: SubjectCatalog

var subject_anchor: Marker3D
var gate_camera: Camera3D
var door: Node3D
var door_top: Node3D
var door_hinge: DoorHinge
var side_window: Node3D
var outside_window_marker: Marker3D
var path_avoid_camera_marker: Marker3D
var peephole_view: SubViewportContainer
var peephole_viewport: SubViewport
var peephole_stage: PeepholeStage

var _subject_instance: Node3D
var _current_def: SubjectDef
var _peephole_def: SubjectDef
var _move_tween: Tween
var _in_peephole: bool = false
var _departing: Array[Node3D] = []
var _departing_tweens: Dictionary = {}
var _accept_handoff_done: bool = false
var _accept_entered_room: bool = false
var _delayed_door_close_armed: bool = false
var _door_close_delay_tween: Tween


func _ready() -> void:
	var parent := get_parent()
	subject_anchor = parent.get_node("world/subject_anchor") as Marker3D
	gate_camera = parent.get_node("Camera3D") as Camera3D
	door = parent.get_node("world/door") as Node3D
	door_top = parent.get_node_or_null("world/door_top") as Node3D
	door_hinge = parent.get_node_or_null("world/door_hinge_marker") as DoorHinge
	side_window = parent.get_node_or_null("world/side_window") as Node3D
	outside_window_marker = parent.get_node_or_null("world/outside_window_marker") as Marker3D
	path_avoid_camera_marker = parent.get_node_or_null("world/path_avoid_camera_marker") as Marker3D
	peephole_view = parent.get_node("PeepholeLayer/PeepholeView") as SubViewportContainer
	if peephole_view:
		peephole_viewport = peephole_view.get_node("SubViewport") as SubViewport
		peephole_stage = peephole_viewport.get_node("PeepholeStage") as PeepholeStage
		peephole_view.visible = false
		peephole_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if door_hinge:
		door_hinge.snap_closed()
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
	_peephole_def = _resolve_peephole_def(subject)
	if peephole_stage and _peephole_def:
		peephole_stage.present(
			_peephole_def.subject_scene,
			_peephole_def.peephole_position,
			_peephole_def.peephole_rotation_degrees,
			_peephole_def.peephole_scale,
			appearance
		)


func apply_peephole_pose(
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float
) -> void:
	if _peephole_def:
		_peephole_def.peephole_position = pose_position
		_peephole_def.peephole_rotation_degrees = pose_rotation_degrees
		_peephole_def.peephole_scale = pose_scale
	if peephole_stage:
		peephole_stage.apply_pose(pose_position, pose_rotation_degrees, pose_scale)


func save_peephole_pose() -> String:
	if not OS.has_feature("editor"):
		return "Save only works when playing from the Godot editor."
	if _peephole_def == null or _peephole_def.resource_path.is_empty():
		return "No SubjectDef path to save."
	var err := ResourceSaver.save(_peephole_def, _peephole_def.resource_path)
	if err != OK:
		return "Save failed (%s)." % error_string(err)
	return "Saved %s" % _peephole_def.resource_path


func get_peephole_pose() -> Dictionary:
	if _peephole_def == null:
		return {
			"position": Vector3.ZERO,
			"rotation_degrees": Vector3.ZERO,
			"scale": 2.5,
		}
	return {
		"position": _peephole_def.peephole_position,
		"rotation_degrees": _peephole_def.peephole_rotation_degrees,
		"scale": _peephole_def.peephole_scale,
	}


func _resolve_peephole_def(subject: SubjectDef) -> SubjectDef:
	if subject == null or subject_catalog == null:
		return null
	return subject_catalog.subject_for(SubjectDef.presented_face_type(subject.true_type))


func clear_subject() -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	if _subject_instance and is_instance_valid(_subject_instance):
		_subject_instance.queue_free()
	_subject_instance = null
	_current_def = null
	_peephole_def = null
	if peephole_stage:
		peephole_stage.clear()


func get_active_subject() -> Node3D:
	if _subject_instance and is_instance_valid(_subject_instance):
		return _subject_instance
	return null


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


func set_door_closed(force: bool = true) -> void:
	if not force and _delayed_door_close_armed:
		return
	_cancel_delayed_door_close()
	if door_hinge:
		door_hinge.snap_closed()
	if side_window and _departing.is_empty():
		side_window.visible = false


func window_walk_duration() -> float:
	return window_walk_distance / maxf(walk_speed, 0.05)


func penalty_walk_duration() -> float:
	return penalty_walk_distance / maxf(walk_speed, 0.05)


static func accept_curve_controls(
	start: Vector3,
	through: Vector3,
	end: Vector3,
	start_handle: float = ACCEPT_START_HANDLE
) -> PackedVector3Array:
	var z_span := maxf(absf(through.z - start.z), 1.0)
	var p1 := start + Vector3(0.0, 0.0, z_span * start_handle)
	p1.y = start.y
	return PackedVector3Array([start, p1, through, end])


static func cubic_bezier_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return (
		u * u * u * p0
		+ 3.0 * u * u * t * p1
		+ 3.0 * u * t * t * p2
		+ t * t * t * p3
	)


static func cubic_bezier_tangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return (
		3.0 * u * u * (p1 - p0)
		+ 6.0 * u * t * (p2 - p1)
		+ 3.0 * t * t * (p3 - p2)
	)


static func cubic_bezier_arc_length(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	samples: int = 32
) -> float:
	var length := 0.0
	var prev := cubic_bezier_point(p0, p1, p2, p3, 0.0)
	for i in range(1, samples + 1):
		var t := float(i) / float(samples)
		var point := cubic_bezier_point(p0, p1, p2, p3, t)
		length += prev.distance_to(point)
		prev = point
	return length


static func accept_curve_pass_t(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	through: Vector3,
	samples: int = 32
) -> float:
	var best_t := 0.0
	var best_distance := INF
	for i in range(0, samples + 1):
		var t := float(i) / float(samples)
		var point := cubic_bezier_point(p0, p1, p2, p3, t)
		var distance := point.distance_squared_to(through)
		if distance < best_distance:
			best_distance = distance
			best_t = t
	return best_t


func accept_path_end(start: Vector3, camera_z: float) -> Vector3:
	var y := start.y
	if path_avoid_camera_marker:
		var through := path_avoid_camera_marker.global_position
		through.y = y
		var end := through + Vector3(0.0, 0.0, walk_past_distance)
		end.y = y
		return end
	return Vector3(start.x, y, camera_z + walk_past_distance)


func play_accept(
	on_complete: Callable = Callable(),
	on_passed_marker: Callable = Callable()
) -> void:
	if side_window:
		side_window.visible = false
	_accept_handoff_done = false
	_accept_entered_room = false
	_cancel_delayed_door_close()
	var walk_through := func() -> void:
		if _subject_instance and _subject_instance.has_method("play_walk"):
			_subject_instance.play_walk()
		_tween_accept_curve(on_complete, on_passed_marker)
	if door_hinge:
		door_hinge.open(walk_through)
	else:
		walk_through.call()


func wrong_accept_knock_delay() -> float:
	if _subject_instance == null or not is_instance_valid(_subject_instance) or gate_camera == null:
		return 0.0
	var travel := wrong_accept_knock_delay_for(
		_subject_instance.global_position.z,
		gate_camera.global_position.z,
		walk_speed
	)
	if door_hinge:
		travel += door_hinge.open_duration
	return maxf(travel, 0.0)


static func wrong_accept_knock_delay_for(
	start_z: float,
	camera_z: float,
	speed: float = WALK_SPEED
) -> float:
	return absf(camera_z - start_z) / maxf(speed, 0.05)


func play_accept_penalty(on_complete: Callable = Callable()) -> void:
	if side_window:
		side_window.visible = false
	_cancel_delayed_door_close()
	var walk_through := func() -> void:
		if _subject_instance and _subject_instance.has_method("play_walk"):
			_subject_instance.play_walk()
		_tween_accept_straight(func() -> void:
			if door_hinge:
				door_hinge.close(on_complete)
			elif on_complete.is_valid():
				on_complete.call()
		)
	if door_hinge:
		door_hinge.open(walk_through)
	else:
		walk_through.call()


func play_reject(
	on_complete: Callable = Callable(),
	on_halfway: Callable = Callable()
) -> Node3D:
	_cancel_delayed_door_close()
	if door_hinge:
		door_hinge.snap_closed()
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
			2.5 / maxf(walk_speed, 0.05),
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
		window_walk_duration(),
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


func _tween_accept_curve(on_complete: Callable, on_passed_marker: Callable = Callable()) -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		if on_passed_marker.is_valid():
			on_passed_marker.call()
		if on_complete.is_valid():
			on_complete.call()
		return
	if _move_tween:
		_move_tween.kill()
	var walker := _subject_instance
	var start := walker.global_position
	var camera_z := gate_camera.global_position.z if gate_camera else start.z
	var end := accept_path_end(start, camera_z)
	start.y = end.y
	if path_avoid_camera_marker == null:
		var duration := start.distance_to(end) / maxf(walk_speed, 0.05)
		_tween_subject(end, func() -> void:
			_finish_accept_path(walker, on_complete, on_passed_marker)
		, duration)
		return
	var through := path_avoid_camera_marker.global_position
	through.y = start.y
	var controls := accept_curve_controls(start, through, end, accept_start_handle)
	var p0 := controls[0]
	var p1 := controls[1]
	var p2 := controls[2]
	var p3 := controls[3]
	var duration := cubic_bezier_arc_length(p0, p1, p2, p3) / maxf(walk_speed, 0.05)
	var pass_t := accept_curve_pass_t(p0, p1, p2, p3, through)
	_move_tween = create_tween()
	_move_tween.tween_method(
		func(t: float) -> void:
			if walker == null or not is_instance_valid(walker):
				return
			var pos := cubic_bezier_point(p0, p1, p2, p3, t)
			walker.global_position = pos
			var tangent := cubic_bezier_tangent(p0, p1, p2, p3, t)
			if tangent.length_squared() > 0.0001:
				walker.look_at(pos + tangent, Vector3.UP, true)
			_try_schedule_accept_door_close(pos.z)
			if t >= pass_t:
				_try_accept_marker_handoff(walker, on_passed_marker),
		0.0,
		1.0,
		duration
	)
	_move_tween.tween_callback(func() -> void:
		_finish_accept_path(walker, on_complete, on_passed_marker)
	)


func _tween_accept_straight(on_complete: Callable) -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		if on_complete.is_valid():
			on_complete.call()
		return
	if _move_tween:
		_move_tween.kill()
	var start := _subject_instance.global_position
	var target := start + Vector3(0.0, 0.0, penalty_walk_distance)
	target.y = start.y
	var duration := penalty_walk_duration()
	_move_tween = create_tween()
	_move_tween.tween_method(
		func(t: float) -> void:
			if _subject_instance == null or not is_instance_valid(_subject_instance):
				return
			var pos := start.lerp(target, t)
			_subject_instance.global_position = pos
			_subject_instance.look_at(pos + Vector3(0.0, 0.0, 1.0), Vector3.UP, true),
		0.0,
		1.0,
		duration
	)
	_move_tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


func _try_accept_marker_handoff(walker: Node3D, on_passed_marker: Callable) -> void:
	if _accept_handoff_done or not on_passed_marker.is_valid():
		return
	_accept_handoff_done = true
	_handoff_accept_walker(walker)
	on_passed_marker.call()


static func has_entered_room(subject_z: float, door_z: float) -> bool:
	return subject_z >= door_z


func _try_schedule_accept_door_close(subject_z: float) -> void:
	if _accept_entered_room or door == null:
		return
	if not has_entered_room(subject_z, door.global_position.z):
		return
	_accept_entered_room = true
	if _door_close_delay_tween:
		_door_close_delay_tween.kill()
		_door_close_delay_tween = null
	_delayed_door_close_armed = true
	_door_close_delay_tween = create_tween()
	_door_close_delay_tween.tween_interval(accept_door_close_delay)
	_door_close_delay_tween.tween_callback(_play_delayed_door_close)


func _play_delayed_door_close() -> void:
	_door_close_delay_tween = null
	if door_hinge:
		door_hinge.close(func() -> void:
			_delayed_door_close_armed = false
		)
	else:
		_delayed_door_close_armed = false


func _cancel_delayed_door_close() -> void:
	if _door_close_delay_tween:
		_door_close_delay_tween.kill()
		_door_close_delay_tween = null
	_delayed_door_close_armed = false


func _handoff_accept_walker(walker: Node3D) -> void:
	if walker == _subject_instance:
		_subject_instance = null
		_current_def = null
	if walker and is_instance_valid(walker) and not _departing.has(walker):
		_departing.append(walker)
	if _move_tween:
		_departing_tweens[walker] = _move_tween
		_move_tween = null


func _finish_accept_path(
	walker: Node3D,
	on_complete: Callable,
	on_passed_marker: Callable
) -> void:
	if not _accept_handoff_done and on_passed_marker.is_valid():
		_try_accept_marker_handoff(walker, on_passed_marker)
	if _accept_handoff_done:
		_finish_departing(walker)
		if on_complete.is_valid():
			on_complete.call()
		return
	if _delayed_door_close_armed:
		if on_complete.is_valid():
			on_complete.call()
		return
	if door_hinge:
		door_hinge.close(on_complete)
	elif on_complete.is_valid():
		on_complete.call()


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
