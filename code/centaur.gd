extends Node3D

## Parents a human torso onto a horse body and hides leftover head/legs.
## When a HorseHead slot exists, grafts a second horse head onto the human neck.

@export var torso_offset := Vector3(0.0, 0.2, -0.3)
@export_group("Horse Head")
@export var neck_offset := Vector3(0.0, 0.0, 0.0)
## How much of the grafted horse neck to keep. 1 is the full neck; 0 is the head only.
@export_range(0.0, 1.0, 0.01) var horse_neck_keep := 0.8
## How much grafted mane to keep past the human shoulders. 0 clips at the shoulders; 1 keeps more down the back.
@export_range(0.0, 1.0, 0.01) var horse_mane_keep := 0.0

const HORSE_ATTACH_BONES: PackedStringArray = ["Shoulders", "Torso3", "Torso"]
const HORSE_NECK_ATTACH_BONES: PackedStringArray = ["Neck", "Neck1", "Neck2", "Neck3"]
const MAN_SHOULDER_L_BONES: PackedStringArray = ["Shoulder.L", "UpperArm.L"]
const MAN_SHOULDER_R_BONES: PackedStringArray = ["Shoulder.R", "UpperArm.R"]
## Horse.glb Main also has Neck and Tail verts; only treat a mix as mane when tail is a real share.
const MANE_TAIL_PRIMARY_FRACTION := 0.15
const HORSE_HIDE_BONES: PackedStringArray = [
	"Neck",
	"Neck1",
	"Neck2",
	"Neck3",
	"Head",
	"Ear1.L",
	"Ear2.L",
	"Ear3.L",
	"Ear4.L",
	"Ear1.R",
	"Ear2.R",
	"Ear3.R",
	"Ear4.R",
]
const MAN_HIDE_BONES: PackedStringArray = [
	"UpperLeg.L",
	"LowerLeg.L",
	"UpperLeg.R",
	"LowerLeg.R",
	"Foot.L",
	"Foot.R",
]
const MAN_HEAD_HIDE_BONES: PackedStringArray = ["Head", "Neck"]
const BONE_HIDE_SCALE := Vector3(0.01, 0.01, 0.01)
## Drop a triangle if any vertex is mostly weighted to a hidden bone.
const HIDDEN_WEIGHT_CLIP := 0.5

@onready var _horse_slot: Node3D = $Horse
@onready var _man_slot: Node3D = $Man
@onready var _horse_head_slot: Node3D = get_node_or_null("HorseHead") as Node3D
@onready var _face: Marker3D = $Face

var _horse: Node3D
var _man: Node3D
var _horse_head: Node3D
var _horse_skeleton: Skeleton3D
var _man_skeleton: Skeleton3D
var _horse_head_skeleton: Skeleton3D
var _shoulder_bone: int = -1
var _hips_bone: int = -1
var _human_neck_bone: int = -1
var _horse_head_neck_bone: int = -1
var _horse_hide_indices: PackedInt32Array = []
var _man_hide_indices: PackedInt32Array = []
var _horse_head_keep_indices: PackedInt32Array = []
var _horse_head_hide_indices: PackedInt32Array = []
var _horse_neck_trim_scale: float = 1.0
var _appearance: Dictionary = {}


func _ready() -> void:
	process_priority = 100
	if not _appearance.is_empty():
		_rebuild_models()


func apply_appearance(appearance: Dictionary) -> void:
	_appearance = appearance
	if is_node_ready():
		_rebuild_models()


func _rebuild_models() -> void:
	if _horse_slot == null or _man_slot == null:
		return
	set_process(true)
	_replace_model(_horse_slot, _appearance.get(ModelCatalog.HORSE_KEY) as PackedScene)
	_replace_model(_man_slot, _appearance.get(ModelCatalog.HUMAN_KEY) as PackedScene)
	_horse = _horse_slot.get_child(0) as Node3D if _horse_slot.get_child_count() > 0 else null
	_man = _man_slot.get_child(0) as Node3D if _man_slot.get_child_count() > 0 else null
	ModelCatalog.normalize(_horse, ModelCatalog.HORSE_KEY)
	ModelCatalog.normalize(_man, ModelCatalog.HUMAN_KEY)
	_horse_skeleton = _find_skeleton(_horse)
	_man_skeleton = _find_skeleton(_man)
	if _horse_skeleton == null or _man_skeleton == null:
		push_error("Centaur: missing Skeleton3D on Horse or Man.")
		set_process(false)
		return
	_shoulder_bone = _find_first_bone(_horse_skeleton, HORSE_ATTACH_BONES)
	_hips_bone = _man_skeleton.find_bone("Hips")
	if _shoulder_bone < 0 or _hips_bone < 0:
		push_error("Centaur: Could not find horse attach or human Hips bone.")
		set_process(false)
		return
	_horse_hide_indices = _bone_indices(_horse_skeleton, HORSE_HIDE_BONES)
	_man_hide_indices = _bone_indices(_man_skeleton, MAN_HIDE_BONES)
	_zero_bone_rest_positions(_horse_skeleton, _horse_hide_indices)
	if not _setup_horse_head():
		return
	if _horse_head_skeleton != null:
		var man_hide_bones := MAN_HIDE_BONES.duplicate()
		man_hide_bones.append_array(MAN_HEAD_HIDE_BONES)
		_man_hide_indices = _bone_indices(_man_skeleton, man_hide_bones)
	var horse_always_hide := PackedInt32Array()
	var horse_mane_hide := PackedInt32Array()
	for bone_index in _horse_hide_indices:
		if _horse_skeleton.get_bone_name(bone_index).begins_with("Neck"):
			horse_mane_hide.append(bone_index)
		else:
			horse_always_hide.append(bone_index)
	_clip_hidden_bone_surfaces(_horse, _horse_skeleton, horse_always_hide, horse_mane_hide)
	if _horse_head_skeleton != null:
		_clip_hidden_bone_surfaces(_horse_head, _horse_head_skeleton, _horse_head_hide_indices)
	play_idle()
	_apply_hidden_bone_scales()
	_glue_torso()
	_glue_neck()
	_clip_horse_head_mane()
	_update_face()


func _uses_horse_head() -> bool:
	return _horse_head_slot != null


func _setup_horse_head() -> bool:
	_horse_head = null
	_horse_head_skeleton = null
	_human_neck_bone = -1
	_horse_head_neck_bone = -1
	_horse_head_keep_indices = PackedInt32Array()
	_horse_head_hide_indices = PackedInt32Array()
	if not _uses_horse_head():
		return true
	_replace_model(_horse_head_slot, _appearance.get(ModelCatalog.HORSE_KEY) as PackedScene)
	_horse_head = _horse_head_slot.get_child(0) as Node3D if _horse_head_slot.get_child_count() > 0 else null
	ModelCatalog.normalize(_horse_head, ModelCatalog.HORSE_KEY)
	_horse_head_skeleton = _find_skeleton(_horse_head)
	if _horse_head_skeleton == null:
		push_error("Centaur: missing Skeleton3D on HorseHead.")
		set_process(false)
		return false
	_human_neck_bone = _man_skeleton.find_bone("Neck")
	_refresh_horse_head_cutoff()
	if _human_neck_bone < 0 or _horse_head_neck_bone < 0:
		push_error("Centaur: Could not find human or grafted horse Neck bone.")
		set_process(false)
		return false
	return true


func _process(_delta: float) -> void:
	if _horse_skeleton == null or _man_skeleton == null:
		return
	_apply_hidden_bone_scales()
	_glue_torso()
	_glue_neck()
	_update_face()


func _replace_model(slot: Node3D, model_scene: PackedScene) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	if model_scene:
		slot.add_child(model_scene.instantiate())


func _glue_torso() -> void:
	var shoulder_world := _bone_world_position(_horse_skeleton, _shoulder_bone)
	var hips_world := _bone_world_position(_man_skeleton, _hips_bone)
	var offset_world := _horse.to_global(torso_offset) - _horse.global_position
	_man.global_position += shoulder_world + offset_world - hips_world


func _glue_neck() -> void:
	if _horse_head_skeleton == null or _human_neck_bone < 0 or _horse_head_neck_bone < 0:
		return
	var human_neck_world := _bone_world_position(_man_skeleton, _human_neck_bone)
	var horse_neck_world := _bone_world_position(_horse_head_skeleton, _horse_head_neck_bone)
	var offset_world := _horse_head.to_global(neck_offset) - _horse_head.global_position
	_horse_head.global_position += human_neck_world + offset_world - horse_neck_world


func _apply_hidden_bone_scales() -> void:
	_collapse_bones(_horse_skeleton, _horse_hide_indices)
	_collapse_bones(_man_skeleton, _man_hide_indices)
	_apply_horse_head_hide()


func _zero_bone_rest_positions(skeleton: Skeleton3D, indices: PackedInt32Array) -> void:
	for bone_index in indices:
		var rest := skeleton.get_bone_rest(bone_index)
		rest.origin = Vector3.ZERO
		skeleton.set_bone_rest(bone_index, rest)


func _collapse_bones(skeleton: Skeleton3D, indices: PackedInt32Array) -> void:
	for bone_index in indices:
		skeleton.set_bone_pose_scale(bone_index, BONE_HIDE_SCALE)
		skeleton.set_bone_pose_position(bone_index, Vector3.ZERO)


func _clip_hidden_bone_surfaces(
	root: Node,
	skeleton: Skeleton3D,
	hidden_indices: PackedInt32Array,
	mane_only_indices: PackedInt32Array = PackedInt32Array()
) -> void:
	if root == null or skeleton == null:
		return
	if hidden_indices.is_empty() and mane_only_indices.is_empty():
		return
	var hidden: Dictionary = {}
	for bone_index in hidden_indices:
		hidden[bone_index] = true
	var mane_hidden: Dictionary = {}
	for bone_index in mane_only_indices:
		mane_hidden[bone_index] = true
	for mesh_instance in _find_mesh_instances(root):
		_clip_mesh_hidden_triangles(mesh_instance, skeleton, hidden, mane_hidden)


func _clip_mesh_hidden_triangles(
	mesh_instance: MeshInstance3D,
	skeleton: Skeleton3D,
	hidden: Dictionary,
	mane_hidden: Dictionary = {}
) -> void:
	var source := mesh_instance.mesh
	if source == null:
		return
	var skin: Skin = mesh_instance.skin
	var clipped := ArrayMesh.new()
	var kept_any := false
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var surface_hidden := hidden.duplicate()
		if not mane_hidden.is_empty() and _surface_is_mane(mesh_instance, skeleton, skin, arrays, surface_index):
			for bone_index in mane_hidden:
				surface_hidden[bone_index] = true
		var kept := _kept_surface_arrays(arrays, skeleton, skin, surface_hidden)
		if kept.is_empty():
			continue
		clipped.add_surface_from_arrays(
			source.surface_get_primitive_type(surface_index),
			kept,
			[],
			{},
			source.surface_get_format(surface_index)
		)
		var material := mesh_instance.get_active_material(surface_index)
		if material:
			clipped.surface_set_material(clipped.get_surface_count() - 1, material)
		kept_any = true
	if kept_any:
		mesh_instance.mesh = clipped


func _kept_surface_arrays(
	arrays: Array,
	skeleton: Skeleton3D,
	skin: Skin,
	hidden: Dictionary
) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones.is_empty() or weights.is_empty():
		return arrays
	var per := bones.size() / verts.size()
	if per <= 0:
		return arrays
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array()
		for vertex_index in verts.size():
			indices.append(vertex_index)
	var kept_indices := PackedInt32Array()
	for tri in range(0, indices.size() - 2, 3):
		var a := indices[tri]
		var b := indices[tri + 1]
		var c := indices[tri + 2]
		if (
			_vertex_hidden_weight(a, bones, weights, per, skeleton, skin, hidden) >= HIDDEN_WEIGHT_CLIP
			or _vertex_hidden_weight(b, bones, weights, per, skeleton, skin, hidden) >= HIDDEN_WEIGHT_CLIP
			or _vertex_hidden_weight(c, bones, weights, per, skeleton, skin, hidden) >= HIDDEN_WEIGHT_CLIP
		):
			continue
		kept_indices.append(a)
		kept_indices.append(b)
		kept_indices.append(c)
	if kept_indices.is_empty():
		return []
	if kept_indices.size() == indices.size() and arrays[Mesh.ARRAY_INDEX] != null:
		return arrays
	var kept := arrays.duplicate()
	kept[Mesh.ARRAY_INDEX] = kept_indices
	return kept


func _vertex_hidden_weight(
	vertex_index: int,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	per: int,
	skeleton: Skeleton3D,
	skin: Skin,
	hidden: Dictionary
) -> float:
	var total := 0.0
	for k in per:
		var array_index := vertex_index * per + k
		if array_index >= bones.size() or array_index >= weights.size():
			break
		var w := weights[array_index]
		if w <= 0.00001:
			continue
		var bone_index := _skin_bind_bone(skeleton, skin, bones[array_index])
		if hidden.has(bone_index):
			total += w
	return total


func _skin_bind_bone(skeleton: Skeleton3D, skin: Skin, bind_index: int) -> int:
	if skin == null or bind_index < 0 or bind_index >= skin.get_bind_count():
		return bind_index
	var bone_index := skin.get_bind_bone(bind_index)
	if bone_index < 0:
		bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
	return bone_index


func _surface_is_mane(
	mesh_instance: MeshInstance3D,
	skeleton: Skeleton3D,
	skin: Skin,
	arrays: Array,
	surface_index: int
) -> bool:
	var material := mesh_instance.get_active_material(surface_index)
	if material and material.resource_name.contains("Hair"):
		return true
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones.is_empty() or weights.is_empty() or skeleton == null:
		return false
	var per := bones.size() / verts.size()
	if per <= 0:
		return false
	var has_neck := false
	var tail_primary := 0
	for vertex_index in verts.size():
		var best_w := -1.0
		var best_name := ""
		for k in per:
			var array_index := vertex_index * per + k
			if array_index >= bones.size() or array_index >= weights.size():
				break
			var w := weights[array_index]
			if w <= 0.00001:
				continue
			var bone_name := skeleton.get_bone_name(_skin_bind_bone(skeleton, skin, bones[array_index]))
			if bone_name.begins_with("Neck"):
				has_neck = true
			if w > best_w:
				best_w = w
				best_name = bone_name
		if best_name.begins_with("Tail"):
			tail_primary += 1
	return has_neck and float(tail_primary) >= float(verts.size()) * MANE_TAIL_PRIMARY_FRACTION


func _clip_horse_head_mane() -> void:
	if _horse_head == null or _horse_head_skeleton == null or _man_skeleton == null:
		return
	_man_skeleton.force_update_all_bone_transforms()
	_horse_head_skeleton.force_update_all_bone_transforms()
	var plane := _mane_clip_plane()
	if plane.normal.is_zero_approx():
		return
	for mesh_instance in _find_mesh_instances(_horse_head):
		_clip_mesh_mane_plane(mesh_instance, _horse_head_skeleton, plane)


func _mane_clip_plane() -> Plane:
	var left := _find_first_bone(_man_skeleton, MAN_SHOULDER_L_BONES)
	var right := _find_first_bone(_man_skeleton, MAN_SHOULDER_R_BONES)
	var torso_bone := _man_skeleton.find_bone("Torso")
	if _hips_bone < 0:
		return Plane()
	var hips_world := _bone_world_position(_man_skeleton, _hips_bone)
	var from_bone := torso_bone if torso_bone >= 0 else _human_neck_bone
	if from_bone < 0:
		return Plane()
	var from_world := _bone_world_position(_man_skeleton, from_bone)
	var along := hips_world - from_world
	if along.length_squared() < 0.000001:
		return Plane()
	var normal := along.normalized()
	var plane_point := from_world
	if left >= 0 and right >= 0:
		plane_point = (
			_bone_world_position(_man_skeleton, left)
			+ _bone_world_position(_man_skeleton, right)
		) * 0.5
	elif left >= 0:
		plane_point = _bone_world_position(_man_skeleton, left)
	elif right >= 0:
		plane_point = _bone_world_position(_man_skeleton, right)
	var torso_len := ModelCatalog.torso_length(_man)
	if torso_len <= 0.00001:
		torso_len = hips_world.distance_to(from_world)
	plane_point += normal * (clampf(horse_mane_keep, 0.0, 1.0) * torso_len)
	return Plane(normal, plane_point)


func _clip_mesh_mane_plane(mesh_instance: MeshInstance3D, skeleton: Skeleton3D, plane: Plane) -> void:
	var source := mesh_instance.mesh
	if source == null:
		return
	var skin: Skin = mesh_instance.skin
	var clipped := ArrayMesh.new()
	var kept_any := false
	var clipped_mane := false
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var kept := arrays
		if _surface_is_mane(mesh_instance, skeleton, skin, arrays, surface_index):
			kept = _kept_surface_arrays_on_plane(arrays, skeleton, skin, plane)
			clipped_mane = true
			if kept.is_empty():
				continue
		clipped.add_surface_from_arrays(
			source.surface_get_primitive_type(surface_index),
			kept,
			[],
			{},
			source.surface_get_format(surface_index)
		)
		var material := mesh_instance.get_active_material(surface_index)
		if material:
			clipped.surface_set_material(clipped.get_surface_count() - 1, material)
		kept_any = true
	if kept_any and clipped_mane:
		mesh_instance.mesh = clipped


func _kept_surface_arrays_on_plane(
	arrays: Array,
	skeleton: Skeleton3D,
	skin: Skin,
	plane: Plane
) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones.is_empty() or weights.is_empty():
		return arrays
	var per := bones.size() / verts.size()
	if per <= 0:
		return arrays
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array()
		for vertex_index in verts.size():
			indices.append(vertex_index)
	var kept_indices := PackedInt32Array()
	for tri in range(0, indices.size() - 2, 3):
		var a := indices[tri]
		var b := indices[tri + 1]
		var c := indices[tri + 2]
		if (
			plane.distance_to(_skinned_vertex_world(verts[a], a, bones, weights, per, skeleton, skin)) > 0.0
			or plane.distance_to(_skinned_vertex_world(verts[b], b, bones, weights, per, skeleton, skin)) > 0.0
			or plane.distance_to(_skinned_vertex_world(verts[c], c, bones, weights, per, skeleton, skin)) > 0.0
		):
			continue
		kept_indices.append(a)
		kept_indices.append(b)
		kept_indices.append(c)
	if kept_indices.is_empty():
		return []
	if kept_indices.size() == indices.size() and arrays[Mesh.ARRAY_INDEX] != null:
		return arrays
	var kept := arrays.duplicate()
	kept[Mesh.ARRAY_INDEX] = kept_indices
	return kept


func _skinned_vertex_world(
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
		if array_index >= bones.size() or array_index >= weights.size():
			break
		var w := weights[array_index]
		if w <= 0.00001:
			continue
		var bind_index := bones[array_index]
		var bone_index := _skin_bind_bone(skeleton, skin, bind_index)
		var bind_pose := Transform3D.IDENTITY
		if skin and bind_index >= 0 and bind_index < skin.get_bind_count():
			bind_pose = skin.get_bind_pose(bind_index)
		posed += w * ((skeleton.get_bone_global_pose(bone_index) * bind_pose) * rest)
		total_w += w
	var local := posed / total_w if total_w > 0.0 else rest
	return skeleton.to_global(local)


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		meshes.append_array(_find_mesh_instances(child))
	return meshes


func _apply_horse_head_hide() -> void:
	if _horse_head_skeleton == null:
		return
	_refresh_horse_head_cutoff()
	for bone_index in _horse_head_hide_indices:
		_horse_head_skeleton.reset_bone_pose(bone_index)
	_horse_head_skeleton.clear_bones_global_pose_override()
	_horse_head_skeleton.force_update_all_bone_transforms()
	var saved: Array[Transform3D] = []
	saved.resize(_horse_head_keep_indices.size())
	for i in _horse_head_keep_indices.size():
		saved[i] = _horse_head_skeleton.get_bone_global_pose(_horse_head_keep_indices[i])
	_collapse_bones(_horse_head_skeleton, _horse_head_hide_indices)
	for i in _horse_head_keep_indices.size():
		_horse_head_skeleton.set_bone_global_pose_override(
			_horse_head_keep_indices[i],
			saved[i],
			1.0,
			true
		)
	_apply_horse_neck_trim()
	_horse_head_skeleton.force_update_all_bone_transforms()


func _refresh_horse_head_cutoff() -> void:
	_horse_head_keep_indices = PackedInt32Array()
	_horse_head_hide_indices = PackedInt32Array()
	_horse_head_neck_bone = -1
	_horse_neck_trim_scale = 1.0
	if _horse_head_skeleton == null:
		return
	var chain := _horse_neck_chain(_horse_head_skeleton)
	if chain.is_empty():
		return
	var last_index := chain.size() - 1
	var param := (1.0 - clampf(horse_neck_keep, 0.0, 1.0)) * float(last_index)
	var attach_index := clampi(int(floor(param)), 0, last_index)
	var trim_scale := 1.0 - (param - float(attach_index))
	if trim_scale <= 0.001 and attach_index < last_index:
		attach_index += 1
		trim_scale = 1.0
	_horse_head_neck_bone = chain[attach_index]
	_horse_neck_trim_scale = trim_scale
	var discarded: Dictionary = {}
	for i in attach_index:
		discarded[chain[i]] = true
	var keep := PackedInt32Array()
	for bone_index in _bone_indices(_horse_head_skeleton, HORSE_HIDE_BONES):
		if discarded.has(bone_index):
			continue
		keep.append(bone_index)
	_horse_head_keep_indices = keep
	_horse_head_hide_indices = _horse_body_hide_indices(_horse_head_skeleton, keep)


func _apply_horse_neck_trim() -> void:
	if _horse_neck_trim_scale >= 0.999:
		return
	if _horse_head_neck_bone < 0:
		return
	var head_bone := _horse_head_skeleton.find_bone("Head")
	if head_bone < 0 or head_bone == _horse_head_neck_bone:
		return
	var trim := maxf(_horse_neck_trim_scale, 0.01)
	var attach_pose := _horse_head_skeleton.get_bone_global_pose(_horse_head_neck_bone)
	var head_pose := _horse_head_skeleton.get_bone_global_pose(head_bone)
	var along := head_pose.origin - attach_pose.origin
	var attach_basis := attach_pose.basis
	if along.length_squared() > 0.000001:
		var length_axis := along.normalized()
		attach_basis.x = attach_pose.basis.x.slide(length_axis) + attach_pose.basis.x.project(length_axis) * trim
		attach_basis.y = attach_pose.basis.y.slide(length_axis) + attach_pose.basis.y.project(length_axis) * trim
		attach_basis.z = attach_pose.basis.z.slide(length_axis) + attach_pose.basis.z.project(length_axis) * trim
	_horse_head_skeleton.set_bone_global_pose_override(
		_horse_head_neck_bone,
		Transform3D(attach_basis, attach_pose.origin),
		1.0,
		true
	)
	var old_head_origin := head_pose.origin
	var new_head_origin := attach_pose.origin.lerp(old_head_origin, trim)
	var head_delta := new_head_origin - old_head_origin
	for bone_index in _horse_head_keep_indices:
		if bone_index == _horse_head_neck_bone:
			continue
		var pose := _horse_head_skeleton.get_bone_global_pose(bone_index)
		if bone_index == head_bone or _horse_head_skeleton.get_bone_name(bone_index).begins_with("Ear"):
			pose.origin += head_delta
		else:
			pose.origin = attach_pose.origin.lerp(pose.origin, trim)
		_horse_head_skeleton.set_bone_global_pose_override(bone_index, pose, 1.0, true)


func _horse_neck_chain(skeleton: Skeleton3D) -> PackedInt32Array:
	var chain := PackedInt32Array()
	for bone_name in HORSE_NECK_ATTACH_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			chain.append(bone_index)
	var head_bone := skeleton.find_bone("Head")
	if head_bone >= 0:
		chain.append(head_bone)
	return chain


func _horse_body_hide_indices(skeleton: Skeleton3D, keep: PackedInt32Array) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for bone_index in skeleton.get_bone_count():
		if keep.has(bone_index):
			continue
		indices.append(bone_index)
	return indices


func _bone_indices(skeleton: Skeleton3D, names: PackedStringArray) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for bone_name in names:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			indices.append(bone_index)
	return indices


func _find_first_bone(skeleton: Skeleton3D, names: PackedStringArray) -> int:
	for bone_name in names:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			return bone_index
	return -1


func _bone_world_position(skeleton: Skeleton3D, bone_index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)


func play_idle() -> void:
	_play_animation(_horse, ["Idle"])
	_play_animation(_man, ["Man_Idle", "Idle"])
	if _horse_head:
		_play_animation(_horse_head, ["Idle"])


func play_walk() -> void:
	_play_animation(_horse, ["Walk"])
	_play_animation(_man, ["Man_Walk", "Walk"])
	if _horse_head:
		_play_animation(_horse_head, ["Walk"])


func _play_animation(root: Node, hints: Array[String]) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	for hint in hints:
		for candidate in player.get_animation_list():
			if candidate != hint and not candidate.ends_with("|%s" % hint):
				continue
			var animation := player.get_animation(candidate)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
			player.play(candidate)
			return


func _update_face() -> void:
	if _face == null:
		return
	var face_skeleton := _horse_head_skeleton if _uses_horse_head() else _man_skeleton
	if face_skeleton == null:
		return
	var head_bone := face_skeleton.find_bone("Head")
	if head_bone >= 0:
		_face.global_position = _bone_world_position(face_skeleton, head_bone)


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


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
