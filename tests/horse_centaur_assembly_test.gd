extends SceneTree

const CENTAUR_SCENE := preload("res://scenes/subjects/centaur.tscn")
const HORSE_CENTAUR_SCENE := preload("res://scenes/subjects/horse_centaur.tscn")

const DOOR_HEIGHT := 2.0
const DOOR_FILL := 0.9
const HIDE_SCALE := Vector3(0.01, 0.01, 0.01)
const HEAD_SCALE_MIN := 0.5
const HEAD_SCALE_MAX := 2.0
const HEIGHT_RATIO_MIN := 0.7
const HEIGHT_RATIO_MAX := 1.45


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var world := Node3D.new()
	root.add_child(world)
	for human_scene in ModelCatalog.HUMAN_MODELS:
		for horse_scene in ModelCatalog.HORSE_MODELS:
			_test_combo(world, human_scene, horse_scene, failures)
	world.free()
	if failures.is_empty():
		print("Horse Centaur assembly: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("Horse Centaur assembly: %d check(s) failed." % failures.size())
		quit(1)


func _test_combo(
	world: Node3D,
	human_scene: PackedScene,
	horse_scene: PackedScene,
	failures: PackedStringArray
) -> void:
	var appearance := {
		ModelCatalog.HUMAN_KEY: human_scene,
		ModelCatalog.HORSE_KEY: horse_scene,
	}
	var label := "%s / %s" % [_scene_stem(human_scene), _scene_stem(horse_scene)]
	var horse_centaur := _spawn(world, HORSE_CENTAUR_SCENE, appearance)
	var centaur := _spawn(world, CENTAUR_SCENE, appearance)
	_check_grafted_head_scale(horse_centaur, label, failures)
	_check_human_head_hidden(horse_centaur, label, failures)
	_check_neck_keep(horse_centaur, appearance, label, failures)
	_check_hidden_head_mesh_clipped(centaur, "%s Centaur" % label, failures)
	_check_hidden_head_mesh_clipped(horse_centaur, "%s Horse Centaur" % label, failures)
	_check_chest_junction(centaur, "%s Centaur" % label, failures)
	_check_chest_junction(horse_centaur, "%s Horse Centaur" % label, failures)
	_check_mane_keep(horse_centaur, appearance, "%s Horse Centaur" % label, failures)
	_check_grafted_body_not_below_belly(horse_centaur, "%s Horse Centaur" % label, failures)
	GateFit.fit_stature(horse_centaur, DOOR_HEIGHT, DOOR_FILL)
	GateFit.fit_stature(centaur, DOOR_HEIGHT, DOOR_FILL)
	_check_horse_grounded(horse_centaur, "%s Horse Centaur" % label, failures)
	_check_horse_grounded(centaur, "%s Centaur" % label, failures)
	_check_fitted_height(horse_centaur, centaur, label, failures)
	horse_centaur.free()
	centaur.free()


func _spawn(world: Node3D, scene: PackedScene, appearance: Dictionary) -> Node3D:
	var subject := scene.instantiate() as Node3D
	world.add_child(subject)
	subject.apply_appearance(appearance)
	if subject.has_method("_process"):
		subject._process(0.0)
		subject._process(0.0)
	return subject


func _check_grafted_head_scale(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var skeleton := _find_skeleton(subject.get_node_or_null("HorseHead"))
	if skeleton == null:
		failures.append("%s: missing HorseHead skeleton." % label)
		return
	var head_bone := skeleton.find_bone("Head")
	if head_bone < 0:
		failures.append("%s: HorseHead has no Head bone." % label)
		return
	var scale := skeleton.get_bone_global_pose(head_bone).basis.get_scale()
	if not _scale_near_identity(scale):
		failures.append(
			"%s: grafted Head pose scale %s, expected near identity."
			% [label, str(scale)]
		)


func _check_neck_keep(
	subject: Node3D,
	appearance: Dictionary,
	label: String,
	failures: PackedStringArray
) -> void:
	var original_keep: float = subject.horse_neck_keep
	var first_neck := _first_neck_bone(_find_skeleton(subject.get_node_or_null("HorseHead")))
	if first_neck < 0:
		failures.append("%s: HorseHead has no neck bone." % label)
		return
	_apply_neck_keep(subject, appearance, 0.0)
	var hidden_skeleton := _find_skeleton(subject.get_node_or_null("HorseHead"))
	if hidden_skeleton == null:
		failures.append("%s: missing HorseHead skeleton after neck keep 0." % label)
		return
	var hidden_scale := hidden_skeleton.get_bone_pose_scale(first_neck)
	if not hidden_scale.is_equal_approx(HIDE_SCALE):
		failures.append(
			"%s: neck keep 0 left bone %s at scale %s, expected hide scale."
			% [label, hidden_skeleton.get_bone_name(first_neck), str(hidden_scale)]
		)
	_apply_neck_keep(subject, appearance, 1.0)
	var full_skeleton := _find_skeleton(subject.get_node_or_null("HorseHead"))
	if full_skeleton == null:
		failures.append("%s: missing HorseHead skeleton after neck keep 1." % label)
		return
	var full_scale := full_skeleton.get_bone_pose_scale(first_neck)
	if full_scale.is_equal_approx(HIDE_SCALE):
		failures.append(
			"%s: neck keep 1 hid bone %s."
			% [label, full_skeleton.get_bone_name(first_neck)]
		)
	_apply_neck_keep(subject, appearance, original_keep)


func _apply_neck_keep(subject: Node3D, appearance: Dictionary, keep: float) -> void:
	subject.horse_neck_keep = keep
	subject.apply_appearance(appearance)
	if subject.has_method("_process"):
		subject._process(0.0)
		subject._process(0.0)


func _first_neck_bone(skeleton: Skeleton3D) -> int:
	if skeleton == null:
		return -1
	for bone_name in ["Neck", "Neck1", "Neck2", "Neck3"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			return bone_index
	return -1


func _check_human_head_hidden(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var skeleton := _find_skeleton(subject.get_node_or_null("Man"))
	if skeleton == null:
		failures.append("%s: missing Man skeleton." % label)
		return
	var head_bone := skeleton.find_bone("Head")
	if head_bone < 0:
		failures.append("%s: Man has no Head bone." % label)
		return
	var scale := skeleton.get_bone_pose_scale(head_bone)
	if not scale.is_equal_approx(HIDE_SCALE):
		failures.append(
			"%s: human Head pose scale %s, expected hide scale %s."
			% [label, str(scale), str(HIDE_SCALE)]
		)


func _check_hidden_head_mesh_clipped(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse := subject.get_node_or_null("Horse") as Node3D
	var skeleton := _find_skeleton(horse)
	if skeleton == null:
		failures.append("%s: missing Horse skeleton for mesh clip check." % label)
		return
	var hidden: Dictionary = {}
	var head_bone := skeleton.find_bone("Head")
	if head_bone >= 0:
		hidden[head_bone] = true
	for bone_index in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_index).begins_with("Ear"):
			hidden[bone_index] = true
	var leftover := _used_hidden_vertex_count(horse, skeleton, hidden)
	if leftover > 0:
		failures.append(
			"%s: Horse mesh still uses %d hidden head/ear vert(s)."
			% [label, leftover]
		)


func _check_chest_junction(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse := subject.get_node_or_null("Horse") as Node3D
	var skeleton := _find_skeleton(horse)
	if skeleton == null:
		failures.append("%s: missing Horse skeleton for chest junction check." % label)
		return
	var attach: Dictionary = {}
	for bone_name in ["Shoulders", "Torso", "Torso3", "Body"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			attach[bone_index] = true
	var neck: Dictionary = {}
	for bone_name in ["Neck", "Neck1", "Neck2", "Neck3"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			neck[bone_index] = true
	if attach.is_empty() or neck.is_empty():
		failures.append("%s: Horse skeleton missing attach or neck bones." % label)
		return
	var ring := 0
	for mesh in _find_body_meshes(horse):
		if mesh.mesh == null or mesh.skin == null:
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty() or bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			if indices.is_empty():
				indices = PackedInt32Array()
				for vertex_index in verts.size():
					indices.append(vertex_index)
			var seen: Dictionary = {}
			for index_i in indices:
				if seen.has(index_i):
					continue
				seen[index_i] = true
				var attach_w := _hidden_weight_from_arrays(
					skeleton, mesh.skin, bones, weights, per, index_i, attach
				)
				var neck_w := _hidden_weight_from_arrays(
					skeleton, mesh.skin, bones, weights, per, index_i, neck
				)
				if attach_w >= 0.1 and neck_w > 0.00001:
					ring += 1
	if ring == 0:
		failures.append("%s: Horse chest junction (withers ring) was deleted." % label)


func _check_mane_keep(
	subject: Node3D,
	appearance: Dictionary,
	label: String,
	failures: PackedStringArray
) -> void:
	var original_keep: float = subject.horse_mane_keep
	_apply_mane_keep(subject, appearance, 0.0)
	var horse_head := subject.get_node_or_null("HorseHead") as Node3D
	if horse_head == null:
		failures.append("%s: missing HorseHead for mane keep check." % label)
		_apply_mane_keep(subject, appearance, original_keep)
		return
	var plane := subject._mane_clip_plane() as Plane
	if plane.normal.is_zero_approx():
		failures.append("%s: could not build mane clip plane." % label)
		_apply_mane_keep(subject, appearance, original_keep)
		return
	var past_shoulders := _mane_verts_past_plane(subject, horse_head, plane)
	if past_shoulders > 0:
		failures.append(
			"%s: horse_mane_keep 0 left %d mane vert(s) past the human shoulder plane."
			% [label, past_shoulders]
		)
	var kept_at_zero := _mane_indexed_vertex_count(subject, horse_head)
	_apply_mane_keep(subject, appearance, 1.0)
	horse_head = subject.get_node_or_null("HorseHead") as Node3D
	var kept_at_one := _mane_indexed_vertex_count(subject, horse_head)
	if kept_at_one <= kept_at_zero:
		failures.append(
			"%s: horse_mane_keep 1 kept %d mane vert(s), not more than keep 0 (%d)."
			% [label, kept_at_one, kept_at_zero]
		)
	_apply_mane_keep(subject, appearance, original_keep)


func _apply_mane_keep(subject: Node3D, appearance: Dictionary, keep: float) -> void:
	subject.horse_mane_keep = keep
	subject.apply_appearance(appearance)
	if subject.has_method("_process"):
		subject._process(0.0)
		subject._process(0.0)


func _mane_indexed_vertex_count(subject: Node3D, horse_head: Node3D) -> int:
	var count := 0
	for mesh in _find_body_meshes(horse_head):
		if mesh.mesh == null or mesh.skin == null:
			continue
		var skeleton := mesh.get_parent() as Skeleton3D
		if skeleton == null:
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			if not subject._surface_is_mane(mesh, skeleton, mesh.skin, arrays, surface_index):
				continue
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				count += verts.size()
			else:
				var seen: Dictionary = {}
				for index_i in indices:
					if seen.has(index_i):
						continue
					seen[index_i] = true
					count += 1
	return count


func _mane_verts_past_plane(subject: Node3D, horse_head: Node3D, plane: Plane) -> int:
	var count := 0
	for mesh in _find_body_meshes(horse_head):
		if mesh.mesh == null or mesh.skin == null:
			continue
		var skeleton := mesh.get_parent() as Skeleton3D
		if skeleton == null:
			continue
		skeleton.force_update_all_bone_transforms()
		for surface_index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			if not subject._surface_is_mane(mesh, skeleton, mesh.skin, arrays, surface_index):
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty() or bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			if indices.is_empty():
				indices = PackedInt32Array()
				for vertex_index in verts.size():
					indices.append(vertex_index)
			var seen: Dictionary = {}
			for index_i in indices:
				if seen.has(index_i):
					continue
				seen[index_i] = true
				var world := _skin_world(
					verts[index_i], index_i, bones, weights, per, skeleton, mesh.skin
				)
				if plane.distance_to(world) > 0.001:
					count += 1
	return count


func _check_grafted_body_not_below_belly(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse := subject.get_node_or_null("Horse") as Node3D
	var horse_head := subject.get_node_or_null("HorseHead") as Node3D
	if horse == null or horse_head == null:
		failures.append("%s: missing Horse or HorseHead for belly clip check." % label)
		return
	var horse_aabb := GateFit.get_subject_aabb(horse)
	var belly_y := horse_aabb.position.y + horse_aabb.size.y * 0.4
	var lowest := INF
	var lowest_bone := ""
	for mesh in _find_body_meshes(horse_head):
		var skeleton := mesh.get_parent() as Skeleton3D
		if skeleton == null or mesh.mesh == null or mesh.skin == null:
			continue
		skeleton.force_update_all_bone_transforms()
		for surface_index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty() or bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			if indices.is_empty():
				indices = PackedInt32Array()
				for vertex_index in verts.size():
					indices.append(vertex_index)
			for index_i in indices:
				var world := _skin_world(
					verts[index_i], index_i, bones, weights, per, skeleton, mesh.skin
				)
				if world.y >= lowest:
					continue
				lowest = world.y
				lowest_bone = _primary_bone_from_arrays(
					skeleton, mesh.skin, bones, weights, per, index_i
				)
	if lowest < belly_y:
		failures.append(
			"%s: grafted HorseHead leftover at y=%.4f (bone %s) below belly y=%.4f."
			% [label, lowest, lowest_bone, belly_y]
		)


func _used_hidden_vertex_count(root: Node, skeleton: Skeleton3D, hidden: Dictionary) -> int:
	var count := 0
	for mesh in _find_body_meshes(root):
		if mesh.mesh == null or mesh.skin == null:
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty() or bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			if indices.is_empty():
				indices = PackedInt32Array()
				for vertex_index in verts.size():
					indices.append(vertex_index)
			var seen: Dictionary = {}
			for index_i in indices:
				if seen.has(index_i):
					continue
				seen[index_i] = true
				if _hidden_weight_from_arrays(skeleton, mesh.skin, bones, weights, per, index_i, hidden) >= 0.5:
					count += 1
	return count


func _hidden_weight_from_arrays(
	skeleton: Skeleton3D,
	skin: Skin,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	per: int,
	vertex_index: int,
	hidden: Dictionary
) -> float:
	var total := 0.0
	for k in per:
		var array_index := vertex_index * per + k
		var w := weights[array_index]
		if w <= 0.00001:
			continue
		var bone_index := _bind_bone(skeleton, skin, bones[array_index])
		if hidden.has(bone_index):
			total += w
	return total


func _primary_bone_from_arrays(
	skeleton: Skeleton3D,
	skin: Skin,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	per: int,
	vertex_index: int
) -> String:
	var best_w := -1.0
	var best := "?"
	for k in per:
		var w := weights[vertex_index * per + k]
		if w <= best_w:
			continue
		best_w = w
		var bone_index := _bind_bone(skeleton, skin, bones[vertex_index * per + k])
		best = skeleton.get_bone_name(bone_index) if bone_index >= 0 else "?"
	return best


func _bind_bone(skeleton: Skeleton3D, skin: Skin, bind_index: int) -> int:
	if skin == null or bind_index < 0 or bind_index >= skin.get_bind_count():
		return bind_index
	var bone_index := skin.get_bind_bone(bind_index)
	if bone_index < 0:
		bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
	return bone_index


func _skin_world(
	rest: Vector3,
	vertex_index: int,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	per: int,
	skeleton: Skeleton3D,
	skin: Skin
) -> Vector3:
	var posed := Vector3.ZERO
	var total_w := 0.0
	for k in per:
		var array_index := vertex_index * per + k
		var w := weights[array_index]
		if w <= 0.00001:
			continue
		var bind_index := bones[array_index]
		var bone_index := _bind_bone(skeleton, skin, bind_index)
		posed += w * ((skeleton.get_bone_global_pose(bone_index) * skin.get_bind_pose(bind_index)) * rest)
		total_w += w
	return skeleton.to_global(posed / total_w if total_w > 0.0 else rest)


func _check_horse_grounded(
	subject: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse := subject.get_node_or_null("Horse") as Node3D
	if horse == null:
		failures.append("%s: missing Horse slot." % label)
		return
	var horse_bottom := GateFit.get_subject_aabb(horse).position.y
	if absf(horse_bottom) > 0.02:
		failures.append(
			"%s: Horse mesh bottom at y=%.4f, expected near 0."
			% [label, horse_bottom]
		)


func _check_fitted_height(
	horse_centaur: Node3D,
	centaur: Node3D,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse_centaur_height := _visual_height(horse_centaur)
	var centaur_height := _visual_height(centaur)
	if centaur_height <= 0.001:
		failures.append("%s: Centaur fitted height is zero." % label)
		return
	var ratio := horse_centaur_height / centaur_height
	if ratio < HEIGHT_RATIO_MIN or ratio > HEIGHT_RATIO_MAX:
		failures.append(
			"%s: Horse Centaur height %.4f vs Centaur %.4f (ratio %.3f, expected %.2f-%.2f)."
			% [
				label,
				horse_centaur_height,
				centaur_height,
				ratio,
				HEIGHT_RATIO_MIN,
				HEIGHT_RATIO_MAX,
			]
		)


func _visual_height(subject: Node3D) -> float:
	var aabb := _body_aabb(subject)
	if aabb.size == Vector3.ZERO:
		return 0.0
	var top_y := aabb.position.y + aabb.size.y
	var horse_head := subject.get_node_or_null("HorseHead")
	if horse_head:
		var skeleton := _find_skeleton(horse_head)
		if skeleton:
			var head_bone := skeleton.find_bone("Head")
			if head_bone >= 0:
				top_y = maxf(
					top_y,
					skeleton.to_global(skeleton.get_bone_global_pose(head_bone).origin).y
				)
	return top_y - aabb.position.y


func _body_aabb(subject: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	for mesh in _find_body_meshes(subject):
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


func _find_body_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		if child.name == "HorseHead":
			continue
		meshes.append_array(_find_body_meshes(child))
	return meshes


func _find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _scale_near_identity(scale: Vector3) -> bool:
	return (
		scale.x >= HEAD_SCALE_MIN
		and scale.y >= HEAD_SCALE_MIN
		and scale.z >= HEAD_SCALE_MIN
		and scale.x <= HEAD_SCALE_MAX
		and scale.y <= HEAD_SCALE_MAX
		and scale.z <= HEAD_SCALE_MAX
	)


func _scene_stem(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()
