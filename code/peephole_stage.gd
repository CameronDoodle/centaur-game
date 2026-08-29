@tool
class_name PeepholeStage
extends Node3D

## Isolated close-up stage. The gate scene is never moved or reframed.

@export var preview_scene: PackedScene:
	set(value):
		preview_scene = value
		if Engine.is_editor_hint() and is_inside_tree():
			present(preview_scene, Vector3.ZERO, Vector3.ZERO, 1.0)

@export_group("View Deviation")
@export_range(0.0, 0.2, 0.001) var position_deviation_x: float = 0.02
@export_range(0.0, 0.2, 0.001) var position_deviation_y: float = 0.02
@export_range(0.0, 0.2, 0.001) var position_deviation_z: float = 0.01
@export_range(0.0, 20.0, 0.1) var pitch_deviation_degrees: float = 4.0
@export_range(0.0, 20.0, 0.1) var yaw_deviation_degrees: float = 8.0
@export_range(0.0, 20.0, 0.1) var roll_deviation_degrees: float = 2.0

@onready var _camera: Camera3D = $Camera3D
@onready var pose_pivot: Marker3D = $LookTarget/PosePivot
@onready var scale_pivot: Marker3D = $LookTarget/PosePivot/ScalePivot

var _subject_instance: Node3D
var _nominal_camera_transform: Transform3D


func _ready() -> void:
	if _camera:
		_nominal_camera_transform = _camera.transform
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
	_restore_nominal_camera()
	if scale_pivot == null:
		return
	for child in scale_pivot.get_children():
		scale_pivot.remove_child(child)
		child.free()


static func random_signed(max_abs: float) -> float:
	if max_abs <= 0.0:
		return 0.0
	return randf_range(-max_abs, max_abs)


static func deviated_camera_transform(
	nominal_transform: Transform3D,
	look_target: Vector3,
	pitch_degrees: float,
	yaw_degrees: float,
	roll_degrees: float,
	position_offset: Vector3 = Vector3.ZERO
) -> Transform3D:
	if (
		pitch_degrees == 0.0
		and yaw_degrees == 0.0
		and roll_degrees == 0.0
		and position_offset == Vector3.ZERO
	):
		return nominal_transform
	var offset := nominal_transform.origin - look_target
	var yaw_rad := deg_to_rad(yaw_degrees)
	var pitch_rad := deg_to_rad(pitch_degrees)
	var orbit_basis := Basis.IDENTITY
	orbit_basis = orbit_basis.rotated(Vector3.UP, yaw_rad)
	orbit_basis = orbit_basis.rotated(orbit_basis.x, pitch_rad)
	var orbited_origin := look_target + orbit_basis * offset
	var result := Transform3D()
	result.origin = orbited_origin
	if orbited_origin.distance_squared_to(look_target) > 0.000001:
		result = result.looking_at(look_target, Vector3.UP)
	else:
		result.basis = nominal_transform.basis
	if roll_degrees != 0.0:
		result.basis = result.basis.rotated(-result.basis.z, deg_to_rad(roll_degrees))
	result.origin += position_offset
	return result


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
	_apply_view_deviation()


func _align_face_to_pivot() -> void:
	var face := _subject_instance.find_child("Face", true, false) as Node3D
	if face == null:
		return
	_subject_instance.global_position -= face.global_position - scale_pivot.global_position


func _look_target_position() -> Vector3:
	if scale_pivot == null:
		return Vector3.ZERO
	return to_local(scale_pivot.global_position)


func _apply_view_deviation() -> void:
	if _camera == null or Engine.is_editor_hint():
		return
	var look_target := _look_target_position()
	var pitch := random_signed(pitch_deviation_degrees)
	var yaw := random_signed(yaw_deviation_degrees)
	var roll := random_signed(roll_deviation_degrees)
	var position_offset := Vector3(
		random_signed(position_deviation_x),
		random_signed(position_deviation_y),
		random_signed(position_deviation_z)
	)
	_camera.transform = deviated_camera_transform(
		_nominal_camera_transform,
		look_target,
		pitch,
		yaw,
		roll,
		position_offset
	)


func _restore_nominal_camera() -> void:
	if _camera == null:
		return
	_camera.transform = _nominal_camera_transform
