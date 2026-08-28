extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _gate_rest() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(-8.198, 4.818, -3.406))


func _run() -> void:
	var failures: PackedStringArray = []
	_test_window_look_rest_origin(failures)
	_test_window_look_rest_yaw(failures)
	if failures.is_empty():
		print("Win camera: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Win camera: %d check(s) failed." % failures.size())
		quit(1)


func _test_window_look_rest_origin(failures: PackedStringArray) -> void:
	var gate_rest := _gate_rest()
	var window_rest := PlayerCamera.window_look_rest(gate_rest)
	if not window_rest.origin.is_equal_approx(gate_rest.origin):
		failures.append(
			"window_look_rest should keep origin %s, got %s."
			% [gate_rest.origin, window_rest.origin]
		)


func _test_window_look_rest_yaw(failures: PackedStringArray) -> void:
	var gate_rest := _gate_rest()
	var window_rest := PlayerCamera.window_look_rest(gate_rest)
	var rest_yaw := gate_rest.basis.get_euler().y
	var window_yaw := window_rest.basis.get_euler().y
	var yaw_delta := wrapf(window_yaw - rest_yaw, -PI, PI)
	if not is_equal_approx(yaw_delta, deg_to_rad(90.0)):
		failures.append(
			"window_look_rest expected +90 deg yaw, got %.2f deg."
			% rad_to_deg(yaw_delta)
		)
