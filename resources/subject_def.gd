class_name SubjectDef
extends Resource

enum TrueType { HUMAN, HORSE, CENTAUR, HORSE_CENTAUR, HUMAN_CENTAUR }
enum ClueKind { HUMAN, HORSE }

@export var true_type: TrueType = TrueType.HUMAN
@export var approach_kind: ClueKind = ClueKind.HUMAN
@export var knock_kind: ClueKind = ClueKind.HUMAN
@export var subject_scene: PackedScene
@export var questions: Array[QuestionDef] = []
@export var reveal_text: String = ""
@export_group("Peephole")
@export var peephole_position := Vector3.ZERO
@export var peephole_rotation_degrees := Vector3.ZERO
@export var peephole_scale := 2.5


static func is_banned(true_type: TrueType) -> bool:
	return (
		true_type == TrueType.CENTAUR
		or true_type == TrueType.HORSE_CENTAUR
		or true_type == TrueType.HUMAN_CENTAUR
	)
