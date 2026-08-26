extends Node3D

@export var model_key: StringName = ModelCatalog.HUMAN_KEY
@export var idle_hints: PackedStringArray = ["Idle"]
@export var walk_hints: PackedStringArray = ["Walk"]

@onready var _model_slot: Node3D = $ModelSlot
@onready var _face: Marker3D = $Face

var _model_instance: Node3D
var _skeleton: Skeleton3D

func _ready() -> void:
	_model_instance = _model_slot.get_child(0) as Node3D if _model_slot.get_child_count() > 0 else null
	if _model_instance:
		ModelCatalog.normalize(_model_instance, model_key)
	_refresh_model_references()
	play_idle()
	_update_face()


func _process(_delta: float) -> void:
	_update_face()


func apply_appearance(appearance: Dictionary) -> void:
	var model_scene := appearance.get(model_key) as PackedScene
	if model_scene == null or _model_slot == null:
		return
	for child in _model_slot.get_children():
		_model_slot.remove_child(child)
		child.queue_free()
	_model_instance = model_scene.instantiate() as Node3D
	_model_slot.add_child(_model_instance)
	ModelCatalog.normalize(_model_instance, model_key)
	_refresh_model_references()
	play_idle()
	_update_face()


func play_idle() -> void:
	_play_hints(idle_hints)


func play_walk() -> void:
	_play_hints(walk_hints)


func _play_hints(hints: PackedStringArray) -> void:
	var player := _find_animation_player(self)
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


func _refresh_model_references() -> void:
	_skeleton = _find_skeleton(_model_instance)


func _update_face() -> void:
	if _face == null or _skeleton == null:
		return
	var head_bone := _skeleton.find_bone("Head")
	if head_bone >= 0:
		_face.global_position = _skeleton.to_global(_skeleton.get_bone_global_pose(head_bone).origin)


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


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
