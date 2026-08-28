extends SceneTree

const SPAWN_ORIGIN := Vector3(10.0, 5.0, 20.0)
const WAYPOINT1_LOCAL := Vector3(0.0, -2.0, -10.0)
const WAYPOINT2_LOCAL := Vector3(-2.0, -5.0, -30.0)
const DESPAWN_LOCAL := Vector3(-2.0, -5.0, -50.0)
const SEGMENT_START := Vector3(1.0, 2.0, 3.0)
const SEGMENT_END := Vector3(4.0, 2.0, 7.0)
const SLOPED_FROM := Vector3(0.0, 5.0, 0.0)
const SLOPED_TO := Vector3(3.0, 8.0, 4.0)
const WALK_SPEED := TitlePath.WALK_SPEED


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_path_points_order(failures)
	_test_path_points_sibling_markers(failures)
	_test_segment_duration(failures)
	_test_planted_origin_y(failures)
	_test_walk_forward(failures)
	_test_default_walker_types(failures)
	_test_walker_scene_for(failures)
	if failures.is_empty():
		print("Title path: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Title path: %d check(s) failed." % failures.size())
		quit(1)


func _test_path_points_order(failures: PackedStringArray) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var spawn := TitlePath.new()
	spawn.position = SPAWN_ORIGIN
	world.add_child(spawn)
	_add_marker(spawn, "waypoint1", WAYPOINT1_LOCAL)
	_add_marker(spawn, "waypoint2", WAYPOINT2_LOCAL)
	_add_marker(spawn, "despawn", DESPAWN_LOCAL)
	var points := spawn.path_points()
	world.free()
	if points.size() != 4:
		failures.append("Expected 4 path points, got %d." % points.size())
		return
	var expected := [
		SPAWN_ORIGIN,
		SPAWN_ORIGIN + WAYPOINT1_LOCAL,
		SPAWN_ORIGIN + WAYPOINT2_LOCAL,
		SPAWN_ORIGIN + DESPAWN_LOCAL,
	]
	for i in range(expected.size()):
		if not points[i].is_equal_approx(expected[i]):
			failures.append(
				"Path point %d expected %s, got %s."
				% [i, expected[i], points[i]]
			)


func _test_path_points_sibling_markers(failures: PackedStringArray) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var spawn := TitlePath.new()
	spawn.position = SPAWN_ORIGIN
	world.add_child(spawn)
	var waypoint1_global := SPAWN_ORIGIN + WAYPOINT1_LOCAL
	var waypoint2_global := SPAWN_ORIGIN + WAYPOINT2_LOCAL
	var despawn_global := SPAWN_ORIGIN + DESPAWN_LOCAL
	_add_marker(world, "waypoint1", waypoint1_global)
	_add_marker(world, "waypoint2", waypoint2_global)
	_add_marker(world, "despawn", despawn_global)
	var points := spawn.path_points()
	world.free()
	if points.size() != 4:
		failures.append(
			"Sibling markers: expected 4 path points, got %d." % points.size()
		)
		return
	var expected := [SPAWN_ORIGIN, waypoint1_global, waypoint2_global, despawn_global]
	for i in range(expected.size()):
		if not points[i].is_equal_approx(expected[i]):
			failures.append(
				"Sibling path point %d expected %s, got %s."
				% [i, expected[i], points[i]]
			)


func _test_segment_duration(failures: PackedStringArray) -> void:
	var distance := SEGMENT_START.distance_to(SEGMENT_END)
	var expected := distance / WALK_SPEED
	var duration := TitlePath.segment_duration(SEGMENT_START, SEGMENT_END, WALK_SPEED)
	if not is_equal_approx(duration, expected):
		failures.append(
			"segment_duration expected %.4f, got %.4f."
			% [expected, duration]
		)


func _test_planted_origin_y(failures: PackedStringArray) -> void:
	var planted := TitlePath.planted_origin_y(1.0, 0.25, 5.0)
	if not is_equal_approx(planted, 5.75):
		failures.append(
			"planted_origin_y expected 5.75, got %.4f."
			% planted
		)


func _test_walk_forward(failures: PackedStringArray) -> void:
	var forward := TitlePath.walk_forward(SLOPED_FROM, SLOPED_TO)
	if not is_equal_approx(forward.y, 0.0):
		failures.append(
			"walk_forward Y expected 0.0, got %.4f."
			% forward.y
		)
	var expected_xz := Vector3(SLOPED_TO.x - SLOPED_FROM.x, 0.0, SLOPED_TO.z - SLOPED_FROM.z)
	if not forward.is_equal_approx(expected_xz):
		failures.append(
			"walk_forward expected %s, got %s."
			% [expected_xz, forward]
		)


func _test_default_walker_types(failures: PackedStringArray) -> void:
	var types := TitlePath.default_walker_types()
	if types.size() != 2:
		failures.append("Expected 2 default walker types, got %d." % types.size())
		return
	if types[0] != SubjectDef.TrueType.HUMAN:
		failures.append("Default walker type 0 expected HUMAN.")
	if types[1] != SubjectDef.TrueType.HORSE:
		failures.append("Default walker type 1 expected HORSE.")


func _test_walker_scene_for(failures: PackedStringArray) -> void:
	var cases := {
		SubjectDef.TrueType.HUMAN: TitlePath.HUMAN_SCENE,
		SubjectDef.TrueType.HORSE: TitlePath.HORSE_SCENE,
		SubjectDef.TrueType.HUMAN_CENTAUR: TitlePath.CENTAUR_SCENE,
		SubjectDef.TrueType.HORSE_CENTAUR: TitlePath.HORSE_CENTAUR_SCENE,
	}
	for true_type in cases:
		var scene := TitlePath.walker_scene_for(true_type)
		if scene != cases[true_type]:
			failures.append(
				"walker_scene_for(%s) returned unexpected scene."
				% SubjectDef.TrueType.keys()[true_type]
			)


func _add_marker(parent: Node3D, marker_name: String, local_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = local_position
	parent.add_child(marker)
