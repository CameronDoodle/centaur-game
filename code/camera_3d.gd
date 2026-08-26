extends Camera3D

@export var idle_speed: float = 1.0
@export var idle_amount: float = 0.05

var time: float = 0.0
@onready var initial_position: Vector3 = position

func _process(delta: float) -> void:
	time += delta * idle_speed
	
	# Calculate offset using sine for vertical and cosine for a subtle horizontal drift
	var bob_y = sin(time) * idle_amount
	var bob_x = cos(time * 0.5) * (idle_amount * 0.5)
	
	position = initial_position + Vector3(bob_x, bob_y, 0.0)
