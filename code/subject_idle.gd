extends Node3D

@export var idle_hint := "Idle"
@export var walk_hint := "Walk"


func _ready() -> void:
	play_idle()


func play_idle() -> void:
	_play_hint(idle_hint, false)


func play_walk() -> void:
	_play_hint(walk_hint, true)


func _play_hint(hint: String, ends_with: bool) -> void:
	var player := _find_animation_player(self)
	if player == null:
		return
	for candidate in player.get_animation_list():
		var matches := candidate.ends_with(hint) if ends_with else hint in candidate
		if matches:
			var animation := player.get_animation(candidate)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
			player.play(candidate)
			return


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
