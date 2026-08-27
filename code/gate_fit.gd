class_name GateFit
extends RefCounted


static func door_world_height(door: Node3D, door_top: Node3D = null) -> float:
	if door and door_top:
		return absf(door_top.global_position.y - door.global_position.y)
	if door is Sprite3D:
		var sprite := door as Sprite3D
		if sprite.texture:
			return sprite.texture.get_height() * sprite.pixel_size * abs(sprite.scale.y)
	return 2.0


static func fit_stature(subject: Node3D, door_height: float, door_fill: float) -> bool:
	var aabb := get_subject_aabb(subject)
	if aabb.size == Vector3.ZERO:
		push_warning("GateFit: no mesh bounds on %s" % subject.name)
		return false
	var mesh_height := _stature_height(subject, aabb)
	if mesh_height <= 0.001:
		return false
	var target_height := door_height * door_fill
	var scale_factor := target_height / mesh_height
	subject.scale *= scale_factor
	subject.global_position.y += -get_ground_y(subject)
	return true


static func get_ground_y(subject: Node3D) -> float:
	var horse := subject.get_node_or_null("Horse") as Node3D
	if horse:
		var horse_aabb := get_subject_aabb(horse)
		if horse_aabb.size != Vector3.ZERO:
			return horse_aabb.position.y
	if _should_ground_to_feet(subject):
		var foot_y := _foot_bottom_y(subject)
		if is_finite(foot_y):
			return foot_y
	return get_subject_aabb(subject).position.y


static func _stature_height(subject: Node3D, aabb: AABB) -> float:
	var top_y := aabb.position.y + aabb.size.y
	var grafted_top := _grafted_head_top_y(subject)
	if is_finite(grafted_top):
		top_y = maxf(top_y, grafted_top)
	return top_y - get_ground_y(subject)


static func get_subject_aabb(subject: Node3D) -> AABB:
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


static func _should_ground_to_feet(subject: Node3D) -> bool:
	return subject.get_node_or_null("Horse") == null


static func _foot_bottom_y(subject: Node3D) -> float:
	var skeleton := _find_skeleton(subject)
	if skeleton == null:
		return NAN
	var foot_names: PackedStringArray = ["Foot.L", "Foot.R"]
	var min_y := INF
	var found := false
	for foot_name in foot_names:
		var bone_index := skeleton.find_bone(foot_name)
		if bone_index < 0:
			continue
		found = true
		var y := skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin).y
		min_y = minf(min_y, y)
	return min_y if found else NAN


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


static func _grafted_head_top_y(subject: Node3D) -> float:
	var horse_head := subject.get_node_or_null("HorseHead") as Node3D
	if horse_head == null:
		return NAN
	var skeleton := _find_skeleton(horse_head)
	if skeleton:
		var head_bone := skeleton.find_bone("Head")
		if head_bone >= 0:
			return skeleton.to_global(skeleton.get_bone_global_pose(head_bone).origin).y
	var face := subject.get_node_or_null("Face") as Node3D
	if face:
		return face.global_position.y
	return NAN


static func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		if child.name == "HorseHead":
			continue
		meshes.append_array(_find_mesh_instances(child))
	return meshes
