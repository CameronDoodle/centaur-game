extends SceneTree

const NOMINAL_CAMERA := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.42))
const FACE_TARGET := Vector3.ZERO
const EPSILON := 0.0001


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_zero_knobs_preserve_nominal(failures)
	_test_sampled_offsets_within_bounds(failures)
	_test_orbit_still_aims_at_face(failures)
	_test_position_shift_decenters_without_reaim(failures)
	if failures.is_empty():
		print("Peephole view: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Peephole view: %d check(s) failed." % failures.size())
		quit(1)


func _test_zero_knobs_preserve_nominal(failures: PackedStringArray) -> void:
	var deviated := PeepholeStage.deviated_camera_transform(
		NOMINAL_CAMERA,
		FACE_TARGET,
		0.0,
		0.0,
		0.0,
		Vector3.ZERO
	)
	if not deviated.is_equal_approx(NOMINAL_CAMERA):
		failures.append(
			"Zero deviation knobs should preserve nominal transform, got %s."
			% deviated
		)


func _test_sampled_offsets_within_bounds(failures: PackedStringArray) -> void:
	var limits := {
		"x": 0.02,
		"y": 0.02,
		"z": 0.01,
		"pitch": 4.0,
		"yaw": 8.0,
		"roll": 2.0,
	}
	for _i in range(200):
		var x := PeepholeStage.random_signed(limits.x)
		var y := PeepholeStage.random_signed(limits.y)
		var z := PeepholeStage.random_signed(limits.z)
		var pitch := PeepholeStage.random_signed(limits.pitch)
		var yaw := PeepholeStage.random_signed(limits.yaw)
		var roll := PeepholeStage.random_signed(limits.roll)
		if absf(x) > limits.x + EPSILON:
			failures.append("position x sample %.4f exceeded %.4f." % [x, limits.x])
			return
		if absf(y) > limits.y + EPSILON:
			failures.append("position y sample %.4f exceeded %.4f." % [y, limits.y])
			return
		if absf(z) > limits.z + EPSILON:
			failures.append("position z sample %.4f exceeded %.4f." % [z, limits.z])
			return
		if absf(pitch) > limits.pitch + EPSILON:
			failures.append("pitch sample %.4f exceeded %.4f." % [pitch, limits.pitch])
			return
		if absf(yaw) > limits.yaw + EPSILON:
			failures.append("yaw sample %.4f exceeded %.4f." % [yaw, limits.yaw])
			return
		if absf(roll) > limits.roll + EPSILON:
			failures.append("roll sample %.4f exceeded %.4f." % [roll, limits.roll])
			return


func _test_orbit_still_aims_at_face(failures: PackedStringArray) -> void:
	var cases := [
		Vector3(3.0, -2.0, 0.0),
		Vector3(-4.0, 6.0, 0.0),
		Vector3(0.0, -8.0, 1.5),
	]
	for angles in cases:
		var deviated := PeepholeStage.deviated_camera_transform(
			NOMINAL_CAMERA,
			FACE_TARGET,
			angles.x,
			angles.y,
			angles.z,
			Vector3.ZERO
		)
		if not _camera_aims_at(deviated, FACE_TARGET):
			failures.append(
				"Orbit deviation %s should still aim at face, forward was %s."
				% [angles, -deviated.basis.z]
			)


func _test_position_shift_decenters_without_reaim(failures: PackedStringArray) -> void:
	var angle_only := PeepholeStage.deviated_camera_transform(
		NOMINAL_CAMERA,
		FACE_TARGET,
		2.0,
		3.0,
		0.0,
		Vector3.ZERO
	)
	var position_shift := Vector3(0.01, -0.005, 0.002)
	var with_shift := PeepholeStage.deviated_camera_transform(
		NOMINAL_CAMERA,
		FACE_TARGET,
		2.0,
		3.0,
		0.0,
		position_shift
	)
	var forward_before := -angle_only.basis.z
	var forward_after := -with_shift.basis.z
	if not forward_before.is_equal_approx(forward_after):
		failures.append(
			"Position shift should not change camera aim: before %s, after %s."
			% [forward_before, forward_after]
		)
	var face_centered := angle_only.affine_inverse() * FACE_TARGET
	var face_shifted := with_shift.affine_inverse() * FACE_TARGET
	if absf(face_centered.x) > 0.02 or absf(face_centered.y) > 0.02:
		failures.append(
			"Angle-only deviation should keep face near optical center, got %s."
			% face_centered
		)
	if face_shifted.is_equal_approx(face_centered):
		failures.append(
			"Position shift should move face off optical center: centered %s, shifted %s."
			% [face_centered, face_shifted]
		)


static func _camera_aims_at(camera_transform: Transform3D, target: Vector3) -> bool:
	var forward := -camera_transform.basis.z
	if forward.length_squared() < EPSILON:
		return false
	var to_target := target - camera_transform.origin
	if to_target.length_squared() < EPSILON:
		return true
	return forward.normalized().is_equal_approx(to_target.normalized())
