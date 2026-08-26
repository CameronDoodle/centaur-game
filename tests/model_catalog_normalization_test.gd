extends SceneTree

const RELATIVE_EPSILON := 0.001


func _initialize() -> void:
	var failures: PackedStringArray = []
	_test_catalog(ModelCatalog.HUMAN_MODELS, ModelCatalog.HUMAN_KEY, failures)
	_test_catalog(ModelCatalog.HORSE_MODELS, ModelCatalog.HORSE_KEY, failures)
	_test_unknown_key(failures)
	_test_empty_model(failures)
	if failures.is_empty():
		print("ModelCatalog normalization: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("ModelCatalog normalization: %d check(s) failed." % failures.size())
		quit(1)


func _test_catalog(
	scenes: Array[PackedScene],
	key: StringName,
	failures: PackedStringArray
) -> void:
	var expected := ModelCatalog.reference_height(key)
	if expected <= 0.0:
		failures.append("No reference height for %s." % key)
		return
	for scene in scenes:
		var instance := scene.instantiate() as Node3D
		if instance == null:
			failures.append("Could not instantiate %s." % scene.resource_path)
			continue
		ModelCatalog.normalize(instance, key)
		var measured := _measured_stature(instance, key)
		var relative := absf(measured - expected) / expected
		if relative > RELATIVE_EPSILON:
			failures.append(
				"%s stature %.6f vs reference %.6f (rel %.6f)."
				% [scene.resource_path, measured, expected, relative]
			)
		var scale_after := instance.scale
		ModelCatalog.normalize(instance, key)
		if not instance.scale.is_equal_approx(scale_after):
			failures.append(
				"%s scale changed on second normalize: %s -> %s."
				% [scene.resource_path, str(scale_after), str(instance.scale)]
			)
		instance.free()


func _measured_stature(instance: Node3D, key: StringName) -> float:
	if key == ModelCatalog.HUMAN_KEY:
		return ModelCatalog.torso_length(instance)
	return ModelCatalog.mesh_height(instance)


func _test_unknown_key(failures: PackedStringArray) -> void:
	var instance := Node3D.new()
	instance.scale = Vector3(2.0, 2.0, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	instance.add_child(mesh_instance)
	var before := instance.scale
	ModelCatalog.normalize(instance, &"not_a_real_key")
	if instance.scale != before:
		failures.append("Unknown key changed scale.")
	instance.free()


func _test_empty_model(failures: PackedStringArray) -> void:
	var instance := Node3D.new()
	instance.scale = Vector3(3.0, 3.0, 3.0)
	var before := instance.scale
	ModelCatalog.normalize(instance, ModelCatalog.HUMAN_KEY)
	if instance.scale != before:
		failures.append("Empty model changed scale.")
	instance.free()
