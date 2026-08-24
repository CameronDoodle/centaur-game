extends Node3D

@export var idle_hint := "Idle"


func _ready() -> void:
	var player := _find_animation_player(self)
	if player == null:
		return
	for candidate in player.get_animation_list():
		if idle_hint in candidate:
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
