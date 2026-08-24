class_name SubjectDef
extends Resource

enum TrueType { HUMAN, HORSE, CENTAUR }

@export var true_type: TrueType = TrueType.HUMAN
@export var approach_stream: AudioStream
@export var knock_stream: AudioStream
@export var subject_scene: PackedScene
@export var questions: Array[QuestionDef] = []
@export var reveal_text: String = ""
