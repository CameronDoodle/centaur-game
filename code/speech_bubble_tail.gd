class_name SpeechBubbleTail
extends Control

const TAIL_WIDTH := 18.0
const TAIL_HEIGHT := 28.0

var fill_color := Color.WHITE
var border_color := Color.BLACK
var border_width := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TAIL_WIDTH, TAIL_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END


func _draw() -> void:
	var attach_top := Vector2(size.x - 5, size.y - 30.00)
	var attach_bottom := Vector2(size.x + 10, size.y - 1.0)
	var tip := Vector2(0.0, 25.0)
	var top_ctrl := Vector2(size.x * 0.58, size.y * 0.8)
	var bottom_ctrl := Vector2(size.x * 0.22, size.y * 0.82)

	var outline := PackedVector2Array()
	_append_quadratic(outline, attach_top, top_ctrl, tip)
	_append_quadratic(outline, tip, bottom_ctrl, attach_bottom)

	var fill := outline.duplicate()
	fill.append(attach_top)
	draw_colored_polygon(fill, fill_color)
	draw_polyline(outline, border_color, border_width, true)


func _append_quadratic(points: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var steps := 8
	var start := 0 if points.is_empty() else 1
	for i in range(start, steps + 1):
		var t := float(i) / float(steps)
		var inv := 1.0 - t
		points.append(inv * inv * p0 + 2.0 * inv * t * p1 + t * t * p2)
