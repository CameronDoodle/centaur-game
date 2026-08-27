@tool
class_name Skybox
extends WorldEnvironment

## Procedural sky for the main scene. Tweak colors and energy in the inspector.

@export_group("Sky")
@export var sky_top_color := Color(0.38, 0.58, 0.82):
	set(value):
		sky_top_color = value
		_apply()
@export var sky_horizon_color := Color(0.86, 0.74, 0.58):
	set(value):
		sky_horizon_color = value
		_apply()
@export_range(0.01, 1.0, 0.001) var sky_curve := 0.12:
	set(value):
		sky_curve = value
		_apply()
@export_range(0.0, 8.0, 0.01) var sky_energy := 1.0:
	set(value):
		sky_energy = value
		_apply()

@export_group("Ground")
@export var ground_horizon_color := Color(0.58, 0.5, 0.4):
	set(value):
		ground_horizon_color = value
		_apply()
@export var ground_bottom_color := Color(0.22, 0.18, 0.14):
	set(value):
		ground_bottom_color = value
		_apply()
@export_range(0.01, 1.0, 0.001) var ground_curve := 0.08:
	set(value):
		ground_curve = value
		_apply()
@export_range(0.0, 8.0, 0.01) var ground_energy := 1.0:
	set(value):
		ground_energy = value
		_apply()

@export_group("Sun Disk")
@export_range(0.0, 90.0, 0.1) var sun_angle_max := 30.0:
	set(value):
		sun_angle_max = value
		_apply()
@export_range(0.001, 1.0, 0.001) var sun_curve := 0.15:
	set(value):
		sun_curve = value
		_apply()

@export_group("Environment")
@export_range(0.0, 8.0, 0.01) var background_energy := 1.0:
	set(value):
		background_energy = value
		_apply()
@export var sky_rotation_degrees := Vector3.ZERO:
	set(value):
		sky_rotation_degrees = value
		_apply()
@export var ambient_light_color := Color(0.72, 0.66, 0.58):
	set(value):
		ambient_light_color = value
		_apply()
@export_range(0.0, 4.0, 0.01) var ambient_light_energy := 0.55:
	set(value):
		ambient_light_energy = value
		_apply()

var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	_apply()


func _apply() -> void:
	if environment == null:
		environment = Environment.new()
	if _sky_material == null:
		_sky_material = ProceduralSkyMaterial.new()

	_sky_material.sky_top_color = sky_top_color
	_sky_material.sky_horizon_color = sky_horizon_color
	_sky_material.sky_curve = sky_curve
	_sky_material.sky_energy_multiplier = sky_energy
	_sky_material.ground_horizon_color = ground_horizon_color
	_sky_material.ground_bottom_color = ground_bottom_color
	_sky_material.ground_curve = ground_curve
	_sky_material.ground_energy_multiplier = ground_energy
	_sky_material.sun_angle_max = sun_angle_max
	_sky_material.sun_curve = sun_curve

	var sky := environment.sky
	if sky == null:
		sky = Sky.new()
		environment.sky = sky
	sky.sky_material = _sky_material

	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = background_energy
	environment.sky_rotation = Vector3(
		deg_to_rad(sky_rotation_degrees.x),
		deg_to_rad(sky_rotation_degrees.y),
		deg_to_rad(sky_rotation_degrees.z)
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient_light_color
	environment.ambient_light_energy = ambient_light_energy
