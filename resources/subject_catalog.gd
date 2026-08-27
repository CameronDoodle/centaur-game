class_name SubjectCatalog
extends Resource

@export var human: SubjectDef
@export var horse: SubjectDef
@export var centaur: SubjectDef
@export var human_centaur: SubjectDef
@export var horse_centaur: SubjectDef


func subject_for(true_type: SubjectDef.TrueType) -> SubjectDef:
	match true_type:
		SubjectDef.TrueType.HUMAN:
			return human
		SubjectDef.TrueType.HORSE:
			return horse
		SubjectDef.TrueType.CENTAUR:
			return centaur
		SubjectDef.TrueType.HUMAN_CENTAUR:
			return human_centaur
		SubjectDef.TrueType.HORSE_CENTAUR:
			return horse_centaur
		_:
			return null
