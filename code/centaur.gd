extends Node3D

## Parents the man's waist onto the horse withers and hides leftover head/legs.

@export var torso_offset := Vector3(0.0, 0.2, -0.3)
@export var horse_idle_hint := "Idle"
@export var man_idle_hint := "Man_Idle"

const HORSE_HIDE_BONES: PackedStringArray = ["Neck", "Head"]
const MAN_HIDE_BONES: PackedStringArray = [
	"UpperLeg.L",
	"LowerLeg.L",
	"UpperLeg.R",
	"LowerLeg.R",
	"Foot.L",
	"Foot.R",
]
const BONE_HIDE_SCALE := Vector3(0.01, 0.01, 0.01)

@onready var _horse: Node3D = $Horse
@onready var _man: Node3D = $Man

var _horse_skeleton: Skeleton3D
var _man_skeleton: Skeleton3D
var _shoulder_bone: int = -1
var _hips_bone: int = -1
var _horse_hide_indices: PackedInt32Array = []
var _man_hide_indices: PackedInt32Array = []


func _ready() -> void:
	process_priority = 100
	_horse_skeleton = _find_skeleton(_horse)
	_man_skeleton = _find_skeleton(_man)
	if _horse_skeleton == null or _man_skeleton == null:
		push_error("Centaur: missing Skeleton3D on Horse or Man.")
		set_process(false)
		return
	_shoulder_bone = _horse_skeleton.find_bone("Shoulders")
	_hips_bone = _man_skeleton.find_bone("Hips")
	if _shoulder_bone < 0 or _hips_bone < 0:
		push_error("Centaur: Could not find Shoulders or Hips bones.")
		set_process(false)
		return
	_horse_hide_indices = _bone_indices(_horse_skeleton, HORSE_HIDE_BONES)
	_man_hide_indices = _bone_indices(_man_skeleton, MAN_HIDE_BONES)
	_zero_bone_rest_positions(_horse_skeleton, _horse_hide_indices)
	_make_unshaded(_horse)
	_make_unshaded(_man)
	_play_idle(_horse, horse_idle_hint)
	_play_idle(_man, man_idle_hint)
	_apply_hidden_bone_scales()
	_glue_torso()


func _process(_delta: float) -> void:
	_apply_hidden_bone_scales()
	_glue_torso()


func _glue_torso() -> void:
	var shoulder_world := _bone_world_position(_horse_skeleton, _shoulder_bone)
	var hips_world := _bone_world_position(_man_skeleton, _hips_bone)
	var offset_world := _horse.to_global(torso_offset) - _horse.global_position
	_man.global_position += shoulder_world + offset_world - hips_world


func _apply_hidden_bone_scales() -> void:
	_collapse_bones(_horse_skeleton, _horse_hide_indices)
	_collapse_bones(_man_skeleton, _man_hide_indices)


func _zero_bone_rest_positions(skeleton: Skeleton3D, indices: PackedInt32Array) -> void:
	for bone_index in indices:
		var rest := skeleton.get_bone_rest(bone_index)
		rest.origin = Vector3.ZERO
		skeleton.set_bone_rest(bone_index, rest)


func _collapse_bones(skeleton: Skeleton3D, indices: PackedInt32Array) -> void:
	for bone_index in indices:
		skeleton.set_bone_pose_scale(bone_index, BONE_HIDE_SCALE)
		skeleton.set_bone_pose_position(bone_index, Vector3.ZERO)


func _bone_indices(skeleton: Skeleton3D, names: PackedStringArray) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for bone_name in names:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			push_warning("Centaur: bone not found: %s" % bone_name)
			continue
		indices.append(bone_index)
	return indices


func _bone_world_position(skeleton: Skeleton3D, bone_index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)


func _play_idle(root: Node, hint: String) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	var anim_name := ""
	for candidate in player.get_animation_list():
		if hint in candidate:
			anim_name = candidate
			break
	if anim_name.is_empty():
		return
	var animation := player.get_animation(anim_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	player.play(anim_name)


func _make_unshaded(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh:
			for surface_index in mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index)
				if material is BaseMaterial3D:
					var unique_material := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
					unique_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mesh_instance.set_surface_override_material(surface_index, unique_material)
	for child in root.get_children():
		_make_unshaded(child)


func _find_skeleton(root: Node) -> Skeleton3D:
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
