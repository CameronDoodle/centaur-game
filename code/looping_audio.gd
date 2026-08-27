extends AudioStreamPlayer


func _ready() -> void:
	_begin.call_deferred()


func _begin() -> void:
	await get_tree().process_frame
	if stream == null or not is_inside_tree():
		return
	play()
