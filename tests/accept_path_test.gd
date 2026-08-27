extends SceneTree

const MAIN_CAMERA_Z := -3.406
const AVOID_MARKER := Vector3(-5.078005, 0.0, -3.5729616)
const SUBJECT_START := Vector3(-8.0, 0.0, -10.7)
const TANGENT_ANGLE_THRESHOLD_DEG := 12.0
const EARLY_STRAIGHT_X_SLACK := 0.45


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_starts_straight(failures)
	_test_curves_toward_avoid(failures)
	_test_bezier_tangent_smoothness(failures)
	_test_accept_end_past_camera(failures)
	_test_accept_pass_t_at_avoid_marker(failures)
	_test_accept_door_close_delay(failures)
	_test_window_walk_duration(failures)
	_test_wrong_accept_knock_delay(failures)
	_test_penalty_path_is_straight(failures)
	if failures.is_empty():
		print("Accept path: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Accept path: %d check(s) failed." % failures.size())
		quit(1)


func _controls() -> PackedVector3Array:
	var through := AVOID_MARKER
	var end := through + Vector3(0.0, 0.0, SubjectPresenter.WALK_PAST_DISTANCE)
	return SubjectPresenter.accept_curve_controls(SUBJECT_START, through, end)


func _test_starts_straight(failures: PackedStringArray) -> void:
	var c := _controls()
	var early := SubjectPresenter.cubic_bezier_point(c[0], c[1], c[2], c[3], 0.12)
	if absf(early.x - SUBJECT_START.x) > EARLY_STRAIGHT_X_SLACK:
		failures.append(
			"Accept path should start straight; early X=%.3f drifted from start X=%.3f."
			% [early.x, SUBJECT_START.x]
		)
	var start_tangent := SubjectPresenter.cubic_bezier_tangent(c[0], c[1], c[2], c[3], 0.0)
	var forward := Vector3(0.0, 0.0, 1.0)
	var angle := rad_to_deg(start_tangent.normalized().angle_to(forward))
	if angle > 4.0:
		failures.append("Accept path start tangent should face +Z (angle=%.2f deg)." % angle)


func _test_curves_toward_avoid(failures: PackedStringArray) -> void:
	var c := _controls()
	var closest := INF
	for i in range(0, 33):
		var t := float(i) / 32.0
		var point := SubjectPresenter.cubic_bezier_point(c[0], c[1], c[2], c[3], t)
		closest = minf(closest, point.distance_to(AVOID_MARKER))
	if closest > 1.25:
		failures.append("Accept path should pass near avoid marker (closest=%.3f)." % closest)


func _test_bezier_tangent_smoothness(failures: PackedStringArray) -> void:
	var c := _controls()
	var prev_tangent := SubjectPresenter.cubic_bezier_tangent(c[0], c[1], c[2], c[3], 0.0).normalized()
	for i in range(1, 33):
		var t := float(i) / 32.0
		var tangent := SubjectPresenter.cubic_bezier_tangent(c[0], c[1], c[2], c[3], t)
		if tangent.length_squared() < 0.0001:
			continue
		tangent = tangent.normalized()
		var angle := rad_to_deg(prev_tangent.angle_to(tangent))
		if angle > TANGENT_ANGLE_THRESHOLD_DEG:
			failures.append(
				"Bezier tangent corner at t=%.2f (angle=%.2f deg)."
				% [t, angle]
			)
			return
		prev_tangent = tangent


func _test_accept_end_past_camera(failures: PackedStringArray) -> void:
	var end := AVOID_MARKER + Vector3(0.0, 0.0, SubjectPresenter.WALK_PAST_DISTANCE)
	if end.z <= MAIN_CAMERA_Z:
		failures.append(
			"Accept path end Z (%.3f) should be past camera Z (%.3f)."
			% [end.z, MAIN_CAMERA_Z]
		)


func _test_accept_pass_t_at_avoid_marker(failures: PackedStringArray) -> void:
	var c := _controls()
	var pass_t := SubjectPresenter.accept_curve_pass_t(c[0], c[1], c[2], c[3], AVOID_MARKER)
	if pass_t <= 0.05 or pass_t >= 0.95:
		failures.append(
			"Accept pass t should be mid-path, got %.3f." % pass_t
		)
		return
	var point := SubjectPresenter.cubic_bezier_point(c[0], c[1], c[2], c[3], pass_t)
	if point.distance_to(AVOID_MARKER) > 1.25:
		failures.append(
			"Accept pass t=%.3f should be near avoid marker (distance=%.3f)."
			% [pass_t, point.distance_to(AVOID_MARKER)]
		)
	var later := SubjectPresenter.cubic_bezier_point(c[0], c[1], c[2], c[3], 1.0)
	if later.distance_to(AVOID_MARKER) <= point.distance_to(AVOID_MARKER):
		failures.append("Accept path should continue past the avoid marker after pass t.")


func _test_accept_door_close_delay(failures: PackedStringArray) -> void:
	var presenter := SubjectPresenter.new()
	if not is_equal_approx(presenter.accept_door_close_delay, SubjectPresenter.ACCEPT_DOOR_CLOSE_DELAY):
		failures.append(
			"Accept door close delay expected %.3f, got %.3f."
			% [SubjectPresenter.ACCEPT_DOOR_CLOSE_DELAY, presenter.accept_door_close_delay]
		)
	presenter.queue_free()
	var door_z := -8.62
	if SubjectPresenter.has_entered_room(SUBJECT_START.z, door_z):
		failures.append("Subject start should be outside the room.")
	if not SubjectPresenter.has_entered_room(door_z, door_z):
		failures.append("Crossing the door Z should count as entering the room.")
	if not SubjectPresenter.has_entered_room(AVOID_MARKER.z, door_z):
		failures.append("Avoid marker should be inside the room.")


func _test_window_walk_duration(failures: PackedStringArray) -> void:
	var presenter := SubjectPresenter.new()
	var expected := presenter.window_walk_distance / presenter.walk_speed
	var duration := presenter.window_walk_duration()
	if not is_equal_approx(duration, expected):
		failures.append(
			"window_walk_duration expected %.4f, got %.4f."
			% [expected, duration]
		)
	presenter.queue_free()


func _test_wrong_accept_knock_delay(failures: PackedStringArray) -> void:
	var expected := absf(MAIN_CAMERA_Z - SUBJECT_START.z) / SubjectPresenter.WALK_SPEED
	var delay := SubjectPresenter.wrong_accept_knock_delay_for(SUBJECT_START.z, MAIN_CAMERA_Z)
	if not is_equal_approx(delay, expected):
		failures.append(
			"wrong_accept_knock_delay expected %.4f, got %.4f."
			% [expected, delay]
		)


func _test_penalty_path_is_straight(failures: PackedStringArray) -> void:
	var start := SUBJECT_START
	var presenter := SubjectPresenter.new()
	var end := start + Vector3(0.0, 0.0, presenter.penalty_walk_distance)
	presenter.queue_free()
	if absf(end.x - start.x) > 0.001:
		failures.append("Penalty accept path should stay on start X axis.")
	var through := AVOID_MARKER
	var curve_end := through + Vector3(0.0, 0.0, SubjectPresenter.WALK_PAST_DISTANCE)
	if end.distance_to(curve_end) < 1.0:
		failures.append("Penalty accept path should not end at the curved accept destination.")
