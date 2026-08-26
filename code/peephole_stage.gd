@tool
class_name PeepholeStage
extends Node3D

## Isolated close-up stage. The gate scene is never moved or reframed.

@export var preview_scene: PackedScene:
	set(value):
		preview_scene = value
		if Engine.is_editor_hint() and is_inside_tree():
			present(preview_scene, Vector3.ZERO, Vector3.ZERO, 1.0)

@onready var pose_pivot: Marker3D = $LookTarget/PosePivot
@onready var scale_pivot: Marker3D = $LookTarget/PosePivot/ScalePivot

var _subject_instance: Node3D


func _ready() -> void:
	if Engine.is_editor_hint() and preview_scene:
		present(preview_scene, Vector3.ZERO, Vector3.ZERO, 1.0)


func present(
	subject_scene: PackedScene,
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float,
	appearance: Dictionary = {}
) -> void:
	clear()
	if subject_scene == null or scale_pivot == null:
		return
	_subject_instance = subject_scene.instantiate() as Node3D
	if _subject_instance == null:
		return
	scale_pivot.add_child(_subject_instance)
	if _subject_instance.has_method("apply_appearance"):
		_subject_instance.apply_appearance(appearance)
	_subject_instance.position = Vector3.ZERO
	_subject_instance.rotation = Vector3.ZERO
	call_deferred("_finish_present", pose_position, pose_rotation_degrees, pose_scale)


func apply_pose(
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float
) -> void:
	if pose_pivot == null or scale_pivot == null:
		return
	pose_pivot.position = pose_position
	pose_pivot.rotation_degrees = pose_rotation_degrees
	var safe_scale := maxf(pose_scale, 0.01)
	scale_pivot.scale = Vector3.ONE * safe_scale


func clear() -> void:
	_subject_instance = null
	if scale_pivot == null:
		return
	for child in scale_pivot.get_children():
		scale_pivot.remove_child(child)
		child.free()


func _finish_present(
	pose_position: Vector3,
	pose_rotation_degrees: Vector3,
	pose_scale: float
) -> void:
	if _subject_instance == null or not is_instance_valid(_subject_instance):
		return
	pose_pivot.position = Vector3.ZERO
	pose_pivot.rotation_degrees = pose_rotation_degrees
	scale_pivot.scale = Vector3.ONE * maxf(pose_scale, 0.01)
	_align_face_to_pivot()
	pose_pivot.position = pose_position
	if _subject_instance.has_method("play_idle"):
		_subject_instance.play_idle()


func _align_face_to_pivot() -> void:
	var face := _subject_instance.find_child("Face", true, false) as Node3D
	if face == null:
		return
	_subject_instance.global_position -= face.global_position - scale_pivot.global_position
