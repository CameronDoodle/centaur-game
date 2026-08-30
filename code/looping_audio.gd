extends AudioStreamPlayer


func _ready() -> void:
	if stream == null:
		return
	if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(stream):
		AudioServer.register_stream_as_sample(stream)
	begin_loop.call_deferred()


func begin_loop() -> void:
	if stream == null or not is_inside_tree() or playing:
		return
	play()
