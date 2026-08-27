extends SceneTree

const CENTAUR_SCENE := preload("res://scenes/subjects/centaur.tscn")
const HORSE_CENTAUR_SCENE := preload("res://scenes/subjects/horse_centaur.tscn")
const HIDE_SCALE := Vector3(0.01, 0.01, 0.01)
const FACE_EPSILON := 0.08
const EXTENT_MARGIN := 0.05


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	for human_scene in ModelCatalog.HUMAN_MODELS:
		for horse_scene in ModelCatalog.HORSE_MODELS:
			await _test_human_headed(human_scene, horse_scene, failures)
			await _test_horse_centaur(human_scene, horse_scene, failures)
	if failures.is_empty():
		print("Centaur assembly: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Centaur assembly: %d check(s) failed." % failures.size())
		quit(1)


func _test_human_headed(
	human_scene: PackedScene,
	horse_scene: PackedScene,
	failures: PackedStringArray
) -> void:
	var label := _pair_label(human_scene, horse_scene)
	var control_tris := _control_horse_triangles(horse_scene)
	var centaur := _spawn(CENTAUR_SCENE, human_scene, horse_scene)
	await process_frame
	var horse_tris := _triangle_count(centaur.get_node("Horse"))
	if horse_tris != control_tris:
		failures.append(
			"%s human-headed Horse mesh tris %d vs control %d; chest/withers surfaces were rewritten."
			% [label, horse_tris, control_tris]
		)
	if centaur.get_node_or_null("HorseHead") != null:
		failures.append("%s human-headed Centaur should not have a HorseHead slot." % label)
	var man_skeleton := _find_skeleton(centaur.get_node("Man"))
	if man_skeleton:
		var head_idx := man_skeleton.find_bone("Head")
		if head_idx >= 0 and man_skeleton.get_bone_pose_scale(head_idx).is_equal_approx(HIDE_SCALE):
			failures.append("%s human-headed Head bone should stay visible." % label)
	var player := _find_animation_player(centaur.get_node("Horse"))
	if player == null or not player.is_playing():
		failures.append("%s human-headed horse body should play idle." % label)
	centaur.play_walk()
	await process_frame
	player = _find_animation_player(centaur.get_node("Horse"))
	if player == null or not player.is_playing():
		failures.append("%s human-headed horse body should play walk." % label)
	centaur.free()


func _test_horse_centaur(
	human_scene: PackedScene,
	horse_scene: PackedScene,
	failures: PackedStringArray
) -> void:
	var label := _pair_label(human_scene, horse_scene)
	var control_tris := _control_horse_triangles(horse_scene)
	var control_extent := _control_horse_extent(horse_scene)
	var extents: Array[float] = []
	var mask_tris: Array[int] = []
	for length in [0.0, 0.5, 1.0]:
		var centaur := _spawn(HORSE_CENTAUR_SCENE, human_scene, horse_scene, length)
		await process_frame
		var body_tris := _triangle_count(centaur.get_node("Horse"))
		if body_tris != control_tris:
			failures.append(
				"%s Horse Centaur body tris %d vs control %d at length %.1f."
				% [label, body_tris, control_tris, length]
			)
		var head_slot := centaur.get_node("HorseHead") as Node3D
		var tris := _triangle_count(head_slot)
		mask_tris.append(tris)
		if tris <= 0:
			failures.append("%s Horse Mask is empty at length %.1f." % [label, length])
		if tris >= control_tris:
			failures.append(
				"%s Horse Mask tris %d should be trimmed below control %d at length %.1f."
				% [label, tris, control_tris, length]
			)
		var extent := GateFit.get_subject_aabb(head_slot).get_longest_axis_size()
		extents.append(extent)
		if extent > control_extent * 0.75:
			failures.append(
				"%s Horse Mask extent %.3f still looks like a full horse (%.3f) at length %.1f."
				% [label, extent, control_extent, length]
			)
		_assert_mask_hides_human(centaur, label, length, failures)
		_assert_no_mask_animation(head_slot, label, length, failures)
		_assert_no_body_leak(centaur, label, length, failures)
		_assert_face_follows_mask(centaur, label, failures)
		_assert_mask_locked_to_human_head(centaur, label, failures)
		if length == 1.0:
			_assert_default_length(centaur, label, failures)
			_assert_gate_fit(centaur, label, failures)
			await process_frame
			_assert_face_follows_mask(centaur, label, failures)
			centaur.play_walk()
			await process_frame
			_assert_no_mask_animation(head_slot, label, length, failures)
			_assert_face_follows_mask(centaur, label, failures)
			_assert_mask_locked_to_human_head(centaur, label, failures)
			var horse_player := _find_animation_player(centaur.get_node("Horse"))
			if horse_player == null or not horse_player.is_playing():
				failures.append("%s Horse Centaur body should play walk." % label)
		centaur.free()
	if mask_tris.size() == 3:
		if mask_tris[0] > mask_tris[1] or mask_tris[1] > mask_tris[2]:
			failures.append(
				"%s Horse Mask triangle counts are not monotonic: %s."
				% [label, str(mask_tris)]
			)
		if mask_tris[2] <= mask_tris[0]:
			failures.append(
				"%s Horse Mask length 1.0 should keep more geometry than length 0.0 (%d vs %d)."
				% [label, mask_tris[2], mask_tris[0]]
			)
	if extents.size() == 3:
		if extents[1] + EXTENT_MARGIN < extents[0] or extents[2] + EXTENT_MARGIN < extents[1]:
			failures.append(
				"%s Horse Mask extent is not monotonic: %s."
				% [label, str(extents)]
			)
		if extents[2] <= extents[0] + EXTENT_MARGIN:
			failures.append(
				"%s Horse Mask length 1.0 should reach farther than length 0.0 (%.3f vs %.3f)."
				% [label, extents[2], extents[0]]
			)


func _assert_default_length(centaur: Node3D, label: String, failures: PackedStringArray) -> void:
	var scene := HORSE_CENTAUR_SCENE.instantiate() as Node3D
	if not is_equal_approx(scene.horse_mask_length, 1.0):
		failures.append(
			"%s Horse Centaur scene default horse_mask_length is %.2f, expected 1.0."
			% [label, scene.horse_mask_length]
		)
	scene.free()
	if not is_equal_approx(centaur.horse_mask_length, 1.0):
		failures.append("%s rebuilt Horse Centaur should use shoulder-length mask." % label)


func _assert_gate_fit(centaur: Node3D, label: String, failures: PackedStringArray) -> void:
	if not GateFit.fit_stature(centaur, 2.0, 0.9):
		failures.append("%s GateFit failed to scale the Horse Centaur." % label)
		return
	var ground_y := GateFit.get_ground_y(centaur)
	var face := centaur.get_node_or_null("Face") as Marker3D
	if face == null:
		failures.append("%s missing Face after GateFit." % label)
		return
	if face.global_position.y <= ground_y + 0.4:
		failures.append(
			"%s Face height %.3f is too close to ground %.3f after GateFit."
			% [label, face.global_position.y, ground_y]
		)
	var aabb := GateFit.get_subject_aabb(centaur)
	var stature := aabb.position.y + aabb.size.y - ground_y
	if stature <= 0.5:
		failures.append("%s GateFit stature %.3f is implausibly small." % [label, stature])


func _assert_mask_hides_human(
	centaur: Node3D,
	label: String,
	length: float,
	failures: PackedStringArray
) -> void:
	var man_skeleton := _find_skeleton(centaur.get_node("Man"))
	if man_skeleton == null:
		failures.append("%s Horse Centaur missing human skeleton at length %.1f." % [label, length])
		return
	for bone_name in ["Head", "Neck"]:
		var bone_index := man_skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		if not man_skeleton.get_bone_pose_scale(bone_index).is_equal_approx(HIDE_SCALE):
			failures.append(
				"%s human %s should stay collapsed under the Horse Mask at length %.1f."
				% [label, bone_name, length]
			)


func _assert_no_mask_animation(head_slot: Node, label: String, length: float, failures: PackedStringArray) -> void:
	var player := _find_animation_player(head_slot)
	if player == null:
		return
	if player.active or player.is_playing():
		failures.append(
			"%s Horse Mask should not play a separate horse-head animation at length %.1f."
			% [label, length]
		)


func _assert_no_body_leak(
	centaur: Node3D,
	label: String,
	length: float,
	failures: PackedStringArray
) -> void:
	var mask_skeleton := _find_skeleton(centaur.get_node("HorseHead"))
	if mask_skeleton == null:
		return
	var head_idx := mask_skeleton.find_bone("Head")
	if head_idx < 0:
		return
	var head_pos := mask_skeleton.to_global(mask_skeleton.get_bone_global_pose(head_idx).origin)
	var leak_bones: PackedStringArray = [
		"Tail1",
		"Tail4",
		"FrontFoot.L",
		"BackFoot.L",
		"FF.L",
		"FFB.L",
	]
	for mesh_instance in _meshes(centaur.get_node("HorseHead")):
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var aabb := mesh_instance.global_transform * mesh_instance.get_aabb()
		for bone_name in leak_bones:
			var bone_index := mask_skeleton.find_bone(bone_name)
			if bone_index < 0:
				continue
			var bone_pos := mask_skeleton.to_global(mask_skeleton.get_bone_global_pose(bone_index).origin)
			if aabb.has_point(bone_pos) and bone_pos.distance_to(head_pos) > 0.6:
				failures.append(
					"%s Horse Mask AABB still reaches %s at length %.1f."
					% [label, bone_name, length]
				)
				return


func _assert_mask_locked_to_human_head(
	centaur: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var man_skeleton := _find_skeleton(centaur.get_node("Man"))
	var mask_skeleton := _find_skeleton(centaur.get_node("HorseHead"))
	if man_skeleton == null or mask_skeleton == null:
		return
	var human_head := man_skeleton.find_bone("Head")
	var mask_head := mask_skeleton.find_bone("Head")
	if human_head < 0 or mask_head < 0:
		return
	var human_pose := man_skeleton.get_bone_global_pose(human_head)
	human_pose.basis = human_pose.basis.orthonormalized()
	var human_pos := man_skeleton.to_global(human_pose.origin)
	var mask_pos := mask_skeleton.to_global(mask_skeleton.get_bone_global_pose(mask_head).origin)
	if human_pos.distance_to(mask_pos) > FACE_EPSILON:
		failures.append(
			"%s Horse Mask Head is %.3f from human Head (expected within %.3f)."
			% [label, human_pos.distance_to(mask_pos), FACE_EPSILON]
		)


func _assert_face_follows_mask(centaur: Node3D, label: String, failures: PackedStringArray) -> void:
	var face := centaur.get_node_or_null("Face") as Marker3D
	var mask_skeleton := _find_skeleton(centaur.get_node("HorseHead"))
	if face == null or mask_skeleton == null:
		failures.append("%s Horse Centaur missing Face or Horse Mask skeleton." % label)
		return
	var head_idx := mask_skeleton.find_bone("Head")
	if head_idx < 0:
		return
	var head_pos := mask_skeleton.to_global(mask_skeleton.get_bone_global_pose(head_idx).origin)
	if face.global_position.distance_to(head_pos) > FACE_EPSILON:
		failures.append(
			"%s Face is %.3f from Horse Mask Head (expected within %.3f)."
			% [label, face.global_position.distance_to(head_pos), FACE_EPSILON]
		)


func _spawn(
	scene: PackedScene,
	human_scene: PackedScene,
	horse_scene: PackedScene,
	mask_length: float = -1.0
) -> Node3D:
	var centaur := scene.instantiate() as Node3D
	if mask_length >= 0.0:
		centaur.horse_mask_length = mask_length
	root.add_child(centaur)
	centaur.apply_appearance({
		ModelCatalog.HUMAN_KEY: human_scene,
		ModelCatalog.HORSE_KEY: horse_scene,
	})
	return centaur


func _control_horse_triangles(horse_scene: PackedScene) -> int:
	var horse := horse_scene.instantiate() as Node3D
	root.add_child(horse)
	ModelCatalog.normalize(horse, ModelCatalog.HORSE_KEY)
	var count := _triangle_count(horse)
	horse.free()
	return count


func _control_horse_extent(horse_scene: PackedScene) -> float:
	var horse := horse_scene.instantiate() as Node3D
	root.add_child(horse)
	ModelCatalog.normalize(horse, ModelCatalog.HORSE_KEY)
	var extent := GateFit.get_subject_aabb(horse).get_longest_axis_size()
	horse.free()
	return extent


func _triangle_count(root_node: Node) -> int:
	var total := 0
	for mesh_instance in _meshes(root_node):
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices and indices.size() > 0:
				total += indices.size() / 3
			else:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				total += verts.size() / 3
	return total


func _pair_label(human_scene: PackedScene, horse_scene: PackedScene) -> String:
	return "%s / %s" % [
		human_scene.resource_path.get_file().get_basename(),
		horse_scene.resource_path.get_file().get_basename(),
	]


func _meshes(root_node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node)
	for child in root_node.get_children():
		meshes.append_array(_meshes(child))
	return meshes


func _find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node == null:
		return null
	if root_node is Skeleton3D:
		return root_node
	for child in root_node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node == null:
		return null
	if root_node is AnimationPlayer:
		return root_node
	for child in root_node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
