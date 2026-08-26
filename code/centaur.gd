extends Node3D

## Parents a human torso onto a horse body and hides leftover head/legs.

@export var torso_offset := Vector3(0.0, 0.2, -0.3)

const HORSE_ATTACH_BONES: PackedStringArray = ["Shoulders", "Torso3", "Torso"]
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
const BONE_HIDE_SCALE := Vector3(0.01, 0.01, 0.01)

@onready var _horse_slot: Node3D = $Horse
@onready var _man_slot: Node3D = $Man
@onready var _face: Marker3D = $Face

var _horse: Node3D
var _man: Node3D
var _horse_skeleton: Skeleton3D
var _man_skeleton: Skeleton3D
var _shoulder_bone: int = -1
var _hips_bone: int = -1
var _horse_hide_indices: PackedInt32Array = []
var _man_hide_indices: PackedInt32Array = []
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
	play_idle()
	_apply_hidden_bone_scales()
	_glue_torso()
	_update_face()


func _process(_delta: float) -> void:
	if _horse_skeleton == null or _man_skeleton == null:
		return
	_apply_hidden_bone_scales()
	_glue_torso()
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
	if _face == null or _man_skeleton == null:
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
