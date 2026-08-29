class_name EncounterPlan
extends RefCounted

var subject: SubjectDef
var questions: Array[QuestionDef] = []
var question_subtitles: Array[String] = []
var approach_stream: AudioStream
var knock_stream: AudioStream
