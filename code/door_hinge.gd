class_name DoorHinge
extends Marker3D

@export_range(-180.0, 180.0, 0.1) var open_angle_degrees := 90.0
@export_range(0.05, 4.0, 0.01) var open_duration := 0.65
@export_range(0.05, 4.0, 0.01) var close_duration := 0.55

var _closed_rotation_y: float
var _tween: Tween


func _ready() -> void:
	_closed_rotation_y = rotation.y


func open(on_complete: Callable = Callable()) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(
		self,
		"rotation:y",
		_closed_rotation_y + deg_to_rad(open_angle_degrees),
		open_duration
	)
	if on_complete.is_valid():
		_tween.tween_callback(on_complete)


func close(on_complete: Callable = Callable()) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation:y", _closed_rotation_y, close_duration)
	if on_complete.is_valid():
		_tween.tween_callback(on_complete)


func snap_closed() -> void:
	_kill_tween()
	rotation.y = _closed_rotation_y


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
