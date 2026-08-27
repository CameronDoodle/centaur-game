extends Node3D

const HUMAN_SCENE := preload("res://scenes/subjects/human.tscn")
const HORSE_SCENE := preload("res://scenes/subjects/horse.tscn")
const CENTAUR_SCENE := preload("res://scenes/subjects/centaur.tscn")
const HORSE_CENTAUR_SCENE := preload("res://scenes/subjects/horse_centaur.tscn")

@export var door_height := 2.0
@export var door_fill := 0.9
@export var row_spacing := 3.5
@export var column_spacing := 2.5


func _ready() -> void:
	_spawn_row(0.0, HUMAN_SCENE, ModelCatalog.HUMAN_MODELS, ModelCatalog.HUMAN_KEY)
	_spawn_row(-row_spacing, HORSE_SCENE, ModelCatalog.HORSE_MODELS, ModelCatalog.HORSE_KEY)
	_spawn_centaur_row(-row_spacing * 2.0, CENTAUR_SCENE)
	_spawn_centaur_row(-row_spacing * 3.0, HORSE_CENTAUR_SCENE)


func _spawn_row(
	row_z: float,
	subject_scene: PackedScene,
	models: Array[PackedScene],
	model_key: StringName
) -> void:
	var appearances: Array[Dictionary] = []
	for model in models:
		appearances.append({model_key: model})
	_spawn_subjects(row_z, subject_scene, appearances)


func _spawn_centaur_row(row_z: float, subject_scene: PackedScene) -> void:
	var appearances: Array[Dictionary] = []
	for human_scene in ModelCatalog.HUMAN_MODELS:
		for horse_scene in ModelCatalog.HORSE_MODELS:
			appearances.append({
				ModelCatalog.HUMAN_KEY: human_scene,
				ModelCatalog.HORSE_KEY: horse_scene,
			})
	_spawn_subjects(row_z, subject_scene, appearances)


func _spawn_subjects(
	row_z: float,
	subject_scene: PackedScene,
	appearances: Array[Dictionary]
) -> void:
	var count := appearances.size()
	var start_x := -((count - 1) * column_spacing) * 0.5
	for i in count:
		var appearance := appearances[i]
		var subject := subject_scene.instantiate() as Node3D
		add_child(subject)
		subject.global_position = Vector3(start_x + i * column_spacing, 0.0, row_z)
		if subject.has_method("apply_appearance"):
			subject.apply_appearance(appearance)
		call_deferred("_fit_and_label", subject, appearance)


func _fit_and_label(subject: Node3D, appearance: Dictionary) -> void:
	GateFit.fit_stature(subject, door_height, door_fill)
	_add_label(subject, _appearance_label(appearance))


func _appearance_label(appearance: Dictionary) -> String:
	var parts: PackedStringArray = []
	if appearance.has(ModelCatalog.HUMAN_KEY):
		parts.append(_scene_stem(appearance[ModelCatalog.HUMAN_KEY] as PackedScene))
	if appearance.has(ModelCatalog.HORSE_KEY):
		parts.append(_scene_stem(appearance[ModelCatalog.HORSE_KEY] as PackedScene))
	return " / ".join(parts)


func _scene_stem(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()


func _add_label(subject: Node3D, text: String) -> void:
	var aabb := GateFit.get_subject_aabb(subject)
	var bottom_center := Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5
	)
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = subject.to_local(bottom_center + Vector3(0.0, -0.15, 0.0))
	subject.add_child(label)
