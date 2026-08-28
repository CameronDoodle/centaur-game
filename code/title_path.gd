class_name TitlePath
extends Marker3D

const SPAWN_INTERVAL := 8.0
const WALK_SPEED := 5.0
const DOOR_FILL := 0.9

const HUMAN_SCENE := preload("res://scenes/subjects/human.tscn")
const HORSE_SCENE := preload("res://scenes/subjects/horse.tscn")
const CENTAUR_SCENE := preload("res://scenes/subjects/centaur.tscn")
const HORSE_CENTAUR_SCENE := preload("res://scenes/subjects/horse_centaur.tscn")

var _spawn_timer: Timer
var _walkers: Array[Node3D] = []
var _walker_tweens: Dictionary = {}
var _walker_types: Array[SubjectDef.TrueType] = []
var _walker_type_index := 0
var _active := false

var _door: Node3D
var _door_top: Node3D


func _ready() -> void:
	var world := get_parent()
	if world:
		_door = world.get_node_or_null("door") as Node3D
		_door_top = world.get_node_or_null("door_top") as Node3D


func path_points() -> PackedVector3Array:
	var points: PackedVector3Array = [global_position]
	for marker_name in ["waypoint1", "waypoint2", "despawn"]:
		var marker := _marker_named(marker_name)
		if marker:
			points.append(marker.global_position)
	return points


func _marker_named(marker_name: String) -> Marker3D:
	var marker := get_node_or_null(marker_name) as Marker3D
	if marker:
		return marker
	var world := get_parent()
	if world:
		return world.get_node_or_null(marker_name) as Marker3D
	return null


static func default_walker_types() -> Array[SubjectDef.TrueType]:
	return [
		SubjectDef.TrueType.HUMAN,
		SubjectDef.TrueType.HORSE,
	]


static func walker_scene_for(true_type: SubjectDef.TrueType) -> PackedScene:
	match true_type:
		SubjectDef.TrueType.HUMAN:
			return HUMAN_SCENE
		SubjectDef.TrueType.HORSE:
			return HORSE_SCENE
		SubjectDef.TrueType.CENTAUR, SubjectDef.TrueType.HUMAN_CENTAUR:
			return CENTAUR_SCENE
		SubjectDef.TrueType.HORSE_CENTAUR:
			return HORSE_CENTAUR_SCENE
		_:
			return HUMAN_SCENE


static func segment_duration(from: Vector3, to: Vector3, speed: float = WALK_SPEED) -> float:
	return from.distance_to(to) / maxf(speed, 0.05)


static func planted_origin_y(origin_y: float, foot_y: float, ground_y: float) -> float:
	return origin_y + (ground_y - foot_y)


static func walk_forward(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x - from.x, 0.0, to.z - from.z)


func begin(types: Array[SubjectDef.TrueType] = []) -> void:
	_walker_types = types if not types.is_empty() else default_walker_types()
	_walker_type_index = 0
	_active = true
	if _spawn_timer == null:
		_spawn_timer = Timer.new()
		_spawn_timer.wait_time = SPAWN_INTERVAL
		_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		add_child(_spawn_timer)
	_spawn_timer.start()
	_spawn_walker()


func end() -> void:
	_active = false
	if _spawn_timer:
		_spawn_timer.stop()
	for tween in _walker_tweens.values():
		if tween is Tween:
			(tween as Tween).kill()
	_walker_tweens.clear()
	for walker in _walkers:
		if is_instance_valid(walker):
			walker.queue_free()
	_walkers.clear()


func _on_spawn_timer_timeout() -> void:
	_spawn_walker()


func _spawn_walker() -> void:
	if not _active or _walker_types.is_empty():
		return
	var points := path_points()
	if points.size() < 2:
		return
	var true_type := _walker_types[_walker_type_index]
	_walker_type_index = (_walker_type_index + 1) % _walker_types.size()
	var scene := walker_scene_for(true_type)
	var walker := scene.instantiate() as Node3D
	var world := get_parent()
	if world == null:
		walker.queue_free()
		return
	world.add_child(walker)
	_walkers.append(walker)
	if walker.has_method("apply_appearance"):
		walker.apply_appearance(ModelCatalog.roll(true_type))
	var door_height := GateFit.door_world_height(_door, _door_top)
	GateFit.fit_stature(walker, door_height, DOOR_FILL)
	var start := points[0]
	walker.global_position.x = start.x
	walker.global_position.z = start.z
	_plant_feet_at(walker, start.y)
	if walker.has_method("play_walk"):
		walker.play_walk()
	_walk_along_path(walker, points, 1)


func _plant_feet_at(walker: Node3D, ground_y: float) -> void:
	walker.global_position.y = planted_origin_y(
		walker.global_position.y,
		GateFit.get_ground_y(walker),
		ground_y
	)


func _walk_along_path(walker: Node3D, points: PackedVector3Array, segment_index: int) -> void:
	if segment_index >= points.size():
		_finish_walker(walker)
		return
	var from := points[segment_index - 1]
	var to := points[segment_index]
	var duration := segment_duration(from, to, WALK_SPEED)
	var tween := create_tween()
	_walker_tweens[walker] = tween
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(walker):
				return
			var pos := from.lerp(to, t)
			walker.global_position.x = pos.x
			walker.global_position.z = pos.z
			_plant_feet_at(walker, pos.y)
			var forward := walk_forward(from, to)
			if forward.length_squared() > 0.0001:
				walker.look_at(walker.global_position + forward.normalized(), Vector3.UP, true),
		0.0,
		1.0,
		duration
	)
	tween.tween_callback(func() -> void:
		_walk_along_path(walker, points, segment_index + 1)
	)


func _finish_walker(walker: Node3D) -> void:
	_walker_tweens.erase(walker)
	_walkers.erase(walker)
	if is_instance_valid(walker):
		walker.queue_free()
