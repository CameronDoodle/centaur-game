extends Node3D

## Parents a human torso onto a horse body and hides leftover head/legs.
## When a HorseHead slot exists, a rigid Horse Mask covers the human head.

@export var torso_offset := Vector3(0.0, 0.2, -0.3)
@export_group("Horse Mask")
## Local offset from the human Head bone, in Head space.
@export var mask_offset := Vector3(0.0, 0.000, 0.0)
## 0 keeps the horse face and ears; 1 keeps neck and mane down to the shoulders.
@export_range(0.0, 1.0, 0.01) var horse_mask_length := 1.0

const HORSE_ATTACH_BONES: PackedStringArray = ["Shoulders", "Torso3", "Torso"]
const HORSE_NECK_BASE_BONES: PackedStringArray = ["Neck", "Neck1", "Neck2", "Neck3"]
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
const MASK_SKULL_KEEP := 0.15
const MASK_PLANE_EPSILON := 0.01

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
var _human_head_bone: int = -1
var _horse_mask_head_bone: int = -1
var _horse_hide_indices: PackedInt32Array = []
var _man_hide_indices: PackedInt32Array = []
var _man_head_hide_indices: PackedInt32Array = []
var _mask_from_head: Transform3D = Transform3D.IDENTITY
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
	_man_head_hide_indices = PackedInt32Array()
	_zero_bone_rest_positions(_horse_skeleton, _horse_hide_indices)
	if not _setup_horse_mask():
		return
	if _uses_horse_mask():
		_man_head_hide_indices = _bone_indices(_man_skeleton, MAN_HEAD_HIDE_BONES)
	play_idle()
	_apply_hidden_bone_scales()
	_glue_torso()
	_bind_mask_to_head()
	_hide_human_head()
	_update_face()


func _uses_horse_mask() -> bool:
	return _horse_head_slot != null


func _setup_horse_mask() -> bool:
	_horse_head = null
	_horse_head_skeleton = null
	_human_head_bone = -1
	_horse_mask_head_bone = -1
	_mask_from_head = Transform3D.IDENTITY
	if not _uses_horse_mask():
		return true
	_replace_model(_horse_head_slot, _appearance.get(ModelCatalog.HORSE_KEY) as PackedScene)
	_horse_head = _horse_head_slot.get_child(0) as Node3D if _horse_head_slot.get_child_count() > 0 else null
	ModelCatalog.normalize(_horse_head, ModelCatalog.HORSE_KEY)
	_horse_head_skeleton = _find_skeleton(_horse_head)
	if _horse_head_skeleton == null:
		push_error("Centaur: missing Skeleton3D on HorseHead.")
		set_process(false)
		return false
	_human_head_bone = _man_skeleton.find_bone("Head")
	_horse_mask_head_bone = _horse_head_skeleton.find_bone("Head")
	if _human_head_bone < 0 or _horse_mask_head_bone < 0:
		push_error("Centaur: Could not find human or Horse Mask Head bone.")
		set_process(false)
		return false
	_freeze_mask_pose()
	_trim_mask_mesh()
	return true


func _freeze_mask_pose() -> void:
	var player := _find_animation_player(_horse_head)
	if player:
		player.stop()
		player.active = false
	_horse_head_skeleton.reset_bone_poses()
	_horse_head_skeleton.force_update_all_bone_transforms()


func _process(_delta: float) -> void:
	if _horse_skeleton == null or _man_skeleton == null:
		return
	_apply_hidden_bone_scales()
	_glue_torso()
	_glue_mask()
	_hide_human_head()
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


func _bind_mask_to_head() -> void:
	if _horse_head == null or _horse_head_skeleton == null:
		return
	if _human_head_bone < 0 or _horse_mask_head_bone < 0:
		return
	_man_skeleton.force_update_all_bone_transforms()
	_horse_head_skeleton.force_update_all_bone_transforms()
	var human_head := _unscaled_bone_world_transform(_man_skeleton, _human_head_bone)
	var mask_head := _unscaled_bone_world_transform(_horse_head_skeleton, _horse_mask_head_bone)
	_horse_head.global_position += human_head.origin - mask_head.origin
	_horse_head_skeleton.force_update_all_bone_transforms()
	human_head = _unscaled_bone_world_transform(_man_skeleton, _human_head_bone)
	_mask_from_head = human_head.affine_inverse() * _horse_head.global_transform
	_glue_mask()


func _glue_mask() -> void:
	if _horse_head == null or _human_head_bone < 0:
		return
	var human_head := _unscaled_bone_world_transform(_man_skeleton, _human_head_bone)
	var offset := Transform3D(Basis.IDENTITY, mask_offset)
	_horse_head.global_transform = human_head * offset * _mask_from_head


func _apply_hidden_bone_scales() -> void:
	_collapse_bones(_horse_skeleton, _horse_hide_indices, true)
	_collapse_bones(_man_skeleton, _man_hide_indices, true)


func _hide_human_head() -> void:
	_collapse_bones(_man_skeleton, _man_head_hide_indices, false)


func _zero_bone_rest_positions(skeleton: Skeleton3D, indices: PackedInt32Array) -> void:
	for bone_index in indices:
		var rest := skeleton.get_bone_rest(bone_index)
		rest.origin = Vector3.ZERO
		skeleton.set_bone_rest(bone_index, rest)


func _collapse_bones(skeleton: Skeleton3D, indices: PackedInt32Array, zero_position: bool) -> void:
	for bone_index in indices:
		skeleton.set_bone_pose_scale(bone_index, BONE_HIDE_SCALE)
		if zero_position:
			skeleton.set_bone_pose_position(bone_index, Vector3.ZERO)


func _trim_mask_mesh() -> void:
	var plane := _mask_cutoff_plane()
	if plane.normal.is_zero_approx():
		return
	for mesh_instance in _find_mesh_instances(_horse_head):
		_clip_mesh_to_plane(mesh_instance, _horse_head_skeleton, plane)


func _mask_cutoff_plane() -> Plane:
	if _horse_head_skeleton == null or _horse_mask_head_bone < 0:
		return Plane()
	var base_bone := _find_first_bone(_horse_head_skeleton, HORSE_NECK_BASE_BONES)
	if base_bone < 0:
		base_bone = _find_first_bone(_horse_head_skeleton, HORSE_ATTACH_BONES)
	if base_bone < 0:
		return Plane()
	_horse_head_skeleton.force_update_all_bone_transforms()
	var head_pos := _bone_world_position(_horse_head_skeleton, _horse_mask_head_bone)
	var base_pos := _bone_world_position(_horse_head_skeleton, base_bone)
	var along := head_pos - base_pos
	if along.length_squared() < 0.000001:
		return Plane()
	var normal := along.normalized()
	var toward_body := -normal
	var near_pos := head_pos
	var best_d := head_pos.dot(toward_body)
	for bone_index in _horse_head_skeleton.get_bone_count():
		var bone_name := _horse_head_skeleton.get_bone_name(bone_index)
		if not bone_name.begins_with("Ear"):
			continue
		var ear_pos := _bone_world_position(_horse_head_skeleton, bone_index)
		var ear_d := ear_pos.dot(toward_body)
		if ear_d > best_d:
			best_d = ear_d
			near_pos = ear_pos
	near_pos += toward_body * (along.length() * MASK_SKULL_KEEP)
	var plane_point := near_pos.lerp(base_pos, clampf(horse_mask_length, 0.0, 1.0))
	return Plane(normal, plane_point)


func _clip_mesh_to_plane(mesh_instance: MeshInstance3D, skeleton: Skeleton3D, plane: Plane) -> void:
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
		var kept := _kept_surface_arrays_on_plane(arrays, mesh_instance, skeleton, skin, plane)
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
	else:
		mesh_instance.visible = false


func _kept_surface_arrays_on_plane(
	arrays: Array,
	mesh_instance: MeshInstance3D,
	skeleton: Skeleton3D,
	skin: Skin,
	plane: Plane
) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
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
			plane.distance_to(_vertex_world(verts[a], a, arrays, mesh_instance, skeleton, skin)) < -MASK_PLANE_EPSILON
			or plane.distance_to(_vertex_world(verts[b], b, arrays, mesh_instance, skeleton, skin)) < -MASK_PLANE_EPSILON
			or plane.distance_to(_vertex_world(verts[c], c, arrays, mesh_instance, skeleton, skin)) < -MASK_PLANE_EPSILON
		):
			continue
		kept_indices.append(a)
		kept_indices.append(b)
		kept_indices.append(c)
	if kept_indices.is_empty():
		return []
	if kept_indices.size() == indices.size() and arrays[Mesh.ARRAY_INDEX] != null:
		return arrays
	return _compact_surface_arrays(arrays, kept_indices)


func _compact_surface_arrays(arrays: Array, kept_indices: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var old_to_new: Dictionary = {}
	var unique := PackedInt32Array()
	for idx in kept_indices:
		if old_to_new.has(idx):
			continue
		old_to_new[idx] = unique.size()
		unique.append(idx)
	var compacted := arrays.duplicate()
	for array_index in Mesh.ARRAY_MAX:
		if array_index == Mesh.ARRAY_INDEX:
			continue
		var src = compacted[array_index]
		if src == null:
			continue
		compacted[array_index] = _remap_vertex_array(src, unique, verts.size())
	var new_indices := PackedInt32Array()
	new_indices.resize(kept_indices.size())
	for i in kept_indices.size():
		new_indices[i] = old_to_new[kept_indices[i]]
	compacted[Mesh.ARRAY_INDEX] = new_indices
	return compacted


func _remap_vertex_array(src, unique: PackedInt32Array, vert_count: int):
	if src is PackedVector3Array:
		var out := PackedVector3Array()
		out.resize(unique.size())
		for i in unique.size():
			out[i] = src[unique[i]]
		return out
	if src is PackedVector2Array:
		var out_v2 := PackedVector2Array()
		out_v2.resize(unique.size())
		for i in unique.size():
			out_v2[i] = src[unique[i]]
		return out_v2
	if src is PackedColorArray:
		var out_color := PackedColorArray()
		out_color.resize(unique.size())
		for i in unique.size():
			out_color[i] = src[unique[i]]
		return out_color
	if src is PackedFloat32Array:
		var floats := src as PackedFloat32Array
		var per: int = floats.size() / vert_count if vert_count > 0 else 0
		if per <= 0:
			return src
		var out_f := PackedFloat32Array()
		out_f.resize(unique.size() * per)
		for i in unique.size():
			var from_base: int = unique[i] * per
			var to_base: int = i * per
			for k in per:
				out_f[to_base + k] = floats[from_base + k]
		return out_f
	if src is PackedInt32Array:
		var ints := src as PackedInt32Array
		var per_i: int = ints.size() / vert_count if vert_count > 0 else 0
		if per_i <= 0:
			return src
		var out_i := PackedInt32Array()
		out_i.resize(unique.size() * per_i)
		for i in unique.size():
			var from_base_i: int = unique[i] * per_i
			var to_base_i: int = i * per_i
			for k in per_i:
				out_i[to_base_i + k] = ints[from_base_i + k]
		return out_i
	if src is PackedByteArray:
		var bytes := src as PackedByteArray
		var per_b: int = bytes.size() / vert_count if vert_count > 0 else 0
		if per_b <= 0:
			return src
		var out_b := PackedByteArray()
		out_b.resize(unique.size() * per_b)
		for i in unique.size():
			var from_base_b: int = unique[i] * per_b
			var to_base_b: int = i * per_b
			for k in per_b:
				out_b[to_base_b + k] = bytes[from_base_b + k]
		return out_b
	return src


func _vertex_world(
	rest: Vector3,
	vertex_index: int,
	arrays: Array,
	mesh_instance: MeshInstance3D,
	skeleton: Skeleton3D,
	skin: Skin
) -> Vector3:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var rest_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if skeleton == null or bones.is_empty() or weights.is_empty() or rest_verts.is_empty():
		return mesh_instance.to_global(rest)
	var per := bones.size() / rest_verts.size()
	if per <= 0:
		return mesh_instance.to_global(rest)
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


func _skin_bind_bone(skeleton: Skeleton3D, skin: Skin, bind_index: int) -> int:
	if skin == null or bind_index < 0 or bind_index >= skin.get_bind_count():
		return bind_index
	var bone_index := skin.get_bind_bone(bind_index)
	if bone_index < 0:
		bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
	return bone_index


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root == null:
		return meshes
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		meshes.append_array(_find_mesh_instances(child))
	return meshes


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


func _unscaled_bone_world_transform(skeleton: Skeleton3D, bone_index: int) -> Transform3D:
	var local := skeleton.get_bone_global_pose(bone_index)
	local.basis = local.basis.orthonormalized()
	return skeleton.global_transform * local


func play_idle() -> void:
	_play_animation(_horse, ["Idle"])
	_play_animation(_man, ["Man_Idle", "Idle"])


func play_walk() -> void:
	_play_animation(_horse, ["Walk"])
	_play_animation(_man, ["Man_Walk", "Walk"])


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
	if _uses_horse_mask() and _horse_head_skeleton != null and _horse_mask_head_bone >= 0:
		_face.global_position = _bone_world_position(_horse_head_skeleton, _horse_mask_head_bone)
		return
	if _man_skeleton == null:
		return
	var head_bone := _man_skeleton.find_bone("Head")
	if head_bone >= 0:
		_face.global_position = _bone_world_position(_man_skeleton, head_bone)


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
