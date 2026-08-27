class_name ModelCatalog
extends RefCounted

const HUMAN_KEY := &"human_scene"
const HORSE_KEY := &"horse_scene"
const _HEIGHT_EPSILON := 0.0001

const HUMAN_MODELS: Array[PackedScene] = [
	preload("res://art/human/Man.glb"),
	preload("res://art/human/Adventurer by Quaternius - 5EGWBMpuXq.glb"),
	preload("res://art/human/Punk by Quaternius - BTALZymknF.glb"),
]

const HORSE_MODELS: Array[PackedScene] = [
	preload("res://art/horse/Horse.glb"),
	preload("res://art/horse/Horse by Quaternius - qvTrSG9pZF.glb"),
	preload("res://art/horse/White Horse by Quaternius - bEdE4rmZy9.glb"),
	preload("res://art/horse/Black Horse.glb"),
]

static var _reference_heights: Dictionary = {}


static func roll(true_type: SubjectDef.TrueType) -> Dictionary:
	var appearance := {}
	match true_type:
		SubjectDef.TrueType.HUMAN:
			appearance[HUMAN_KEY] = HUMAN_MODELS.pick_random()
		SubjectDef.TrueType.HORSE:
			appearance[HORSE_KEY] = HORSE_MODELS.pick_random()
		SubjectDef.TrueType.CENTAUR, SubjectDef.TrueType.HORSE_CENTAUR, SubjectDef.TrueType.HUMAN_CENTAUR:
			appearance[HUMAN_KEY] = HUMAN_MODELS.pick_random()
			appearance[HORSE_KEY] = HORSE_MODELS.pick_random()
	return appearance


static func normalize(model: Node3D, model_key: StringName) -> void:
	if model == null:
		push_warning("ModelCatalog: missing model for key '%s'." % model_key)
		return
	if not _is_known_key(model_key):
		push_warning("ModelCatalog: unknown appearance key '%s'." % model_key)
		return
	var target_height := reference_height(model_key)
	if target_height <= _HEIGHT_EPSILON:
		push_warning("ModelCatalog: reference height is unmeasurable for key '%s'." % model_key)
		return
	var current_height := stature(model, model_key)
	if current_height <= _HEIGHT_EPSILON:
		push_warning("ModelCatalog: model height is unmeasurable for key '%s'." % model_key)
		return
	model.scale *= target_height / current_height


static func reference_height(model_key: StringName) -> float:
	if _reference_heights.has(model_key):
		return float(_reference_heights[model_key])
	var scene := _reference_scene(model_key)
	if scene == null:
		return 0.0
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return 0.0
	var height := stature(instance, model_key)
	instance.free()
	_reference_heights[model_key] = height
	return height


static func stature(model: Node3D, model_key: StringName) -> float:
	if model_key == HUMAN_KEY:
		var torso := torso_length(model)
		if torso > _HEIGHT_EPSILON:
			return torso
	return mesh_height(model)


static func torso_length(model: Node3D) -> float:
	if model == null:
		return 0.0
	return _torso_length_recursive(model, model.transform)


static func _torso_length_recursive(node: Node, from_model_parent: Transform3D) -> float:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var hips_idx := skeleton.find_bone("Hips")
		var head_idx := skeleton.find_bone("Head")
		if hips_idx >= 0 and head_idx >= 0:
			var hips_pos := from_model_parent * skeleton.get_bone_global_rest(hips_idx).origin
			var head_pos := from_model_parent * skeleton.get_bone_global_rest(head_idx).origin
			return hips_pos.distance_to(head_pos)
		return 0.0
	for child in node.get_children():
		var child_from_parent := from_model_parent
		if child is Node3D:
			child_from_parent = from_model_parent * (child as Node3D).transform
		var length := _torso_length_recursive(child, child_from_parent)
		if length > _HEIGHT_EPSILON:
			return length
	return 0.0


static func mesh_height(model: Node3D) -> float:
	if model == null:
		return 0.0
	return _merged_mesh_aabb(model, model.transform).size.y


static func _merged_mesh_aabb(node: Node, from_model_parent: Transform3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	if node is MeshInstance3D:
		var local_aabb := (node as MeshInstance3D).get_aabb()
		if not local_aabb.size.is_zero_approx():
			merged = from_model_parent * local_aabb
			has_bounds = true
	for child in node.get_children():
		var child_from_parent := from_model_parent
		if child is Node3D:
			child_from_parent = from_model_parent * (child as Node3D).transform
		var child_aabb := _merged_mesh_aabb(child, child_from_parent)
		if child_aabb.size.is_zero_approx():
			continue
		if has_bounds:
			merged = merged.merge(child_aabb)
		else:
			merged = child_aabb
			has_bounds = true
	return merged if has_bounds else AABB()


static func _reference_scene(model_key: StringName) -> PackedScene:
	match model_key:
		HUMAN_KEY:
			return HUMAN_MODELS[0] if not HUMAN_MODELS.is_empty() else null
		HORSE_KEY:
			return HORSE_MODELS[0] if not HORSE_MODELS.is_empty() else null
		_:
			return null


static func _is_known_key(model_key: StringName) -> bool:
	return model_key == HUMAN_KEY or model_key == HORSE_KEY
