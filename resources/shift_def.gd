class_name ShiftDef
extends Resource

@export_group("Subject pool")
@export var include_human: bool = true
@export var include_horse: bool = true
@export var include_centaur: bool = true
@export var include_human_centaur: bool = true
@export var include_horse_centaur: bool = true
@export var subject_count: int = 5

@export_group("Difficulty")
@export var strikes_allowed: int = 3
@export var shift_timer_seconds: float = 120.0

@export_group("Deception")
@export var human_centaur_can_lie: bool = false
@export_range(0.0, 1.0, 0.01) var human_centaur_lie_chance: float = 0.0
@export var horse_centaur_can_lie: bool = false
@export_range(0.0, 1.0, 0.01) var horse_centaur_lie_chance: float = 0.0


func lie_chance_for(true_type: SubjectDef.TrueType) -> float:
	match true_type:
		SubjectDef.TrueType.HUMAN_CENTAUR:
			return human_centaur_lie_chance if human_centaur_can_lie else 0.0
		SubjectDef.TrueType.HORSE_CENTAUR:
			return horse_centaur_lie_chance if horse_centaur_can_lie else 0.0
		_:
			return 0.0


func enabled_types() -> Array[SubjectDef.TrueType]:
	var types: Array[SubjectDef.TrueType] = []
	if include_human:
		types.append(SubjectDef.TrueType.HUMAN)
	if include_horse:
		types.append(SubjectDef.TrueType.HORSE)
	if include_centaur:
		types.append(SubjectDef.TrueType.CENTAUR)
	if include_human_centaur:
		types.append(SubjectDef.TrueType.HUMAN_CENTAUR)
	if include_horse_centaur:
		types.append(SubjectDef.TrueType.HORSE_CENTAUR)
	return types
