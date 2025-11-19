extends Node2D
class_name BloodDecal

const DEFAULT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/blood/sEfBloodSpray1_0.png"),
	preload("res://assets/blood/sEfBloodSpray1_1.png"),
	preload("res://assets/blood/sEfBloodSpray1_2.png"),
	preload("res://assets/blood/sEfBloodSpray1_3.png"),
	preload("res://assets/blood/sEfBloodSpray1old_0.png"),
	preload("res://assets/blood/sEfBloodSpray1old_1.png"),
	preload("res://assets/blood/sEfBloodSpray1old_2.png"),
	preload("res://assets/blood/sEfBloodSpray1old_3.png"),
	preload("res://assets/blood/sEfBloodSpray2_0.png"),
	preload("res://assets/blood/sEfBloodSpray2_1.png"),
	preload("res://assets/blood/sEfBloodSpray2_2.png"),
	preload("res://assets/blood/sEfBloodSpray2_3.png"),
	preload("res://assets/blood/sEfBloodSpray3_0.png"),
	preload("res://assets/blood/sEfBloodSpray3_1.png"),
	preload("res://assets/blood/sEfBloodSpray3_2.png"),
	preload("res://assets/blood/sEfBloodSpray3_3.png")
]

@export var textures: Array[Texture2D] = DEFAULT_TEXTURES
@export_range(0.1, 3.0, 0.01) var min_scale: float = 0.75
@export_range(0.1, 3.0, 0.01) var max_scale: float = 1.35
@export_range(0.0, 1.0, 0.01) var max_alpha: float = 0.88
@export var depth_offset: float = 2.0
@export var tangent_jitter: float = 6.0
@export var z_layer: int = 10

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	z_index = z_layer
	if sprite:
		sprite.centered = true
		sprite.rotation = 0.0
		if Engine.is_editor_hint():
			if textures.size() > 0 and sprite.texture == null:
				sprite.texture = textures[0]
			sprite.modulate = Color(1.0, 0.95, 0.95, max_alpha)

func setup(world_position: Vector2, surface_normal: Vector2, rng: RandomNumberGenerator) -> void:
	if not sprite:
		return
	if textures.is_empty():
		return
	var normal := surface_normal
	if normal == Vector2.ZERO:
		normal = Vector2.UP
	normal = normal.normalized()

	var index := rng.randi_range(0, textures.size() - 1)
	sprite.texture = textures[index]

	var tangent := Vector2(-normal.y, normal.x)
	var jitter := tangent * rng.randf_range(-tangent_jitter, tangent_jitter)
	global_position = world_position + normal * depth_offset + jitter

	var base_rotation := normal.angle() + PI / 2.0
	rotation = base_rotation + deg_to_rad(rng.randf_range(-12.0, 12.0))

	var scale_value := rng.randf_range(min_scale, max_scale)
	var scale_x := scale_value
	if rng.randf() > 0.5:
		scale_x *= -1.0
	scale = Vector2(scale_x, scale_value)

	var tint := rng.randf_range(0.88, 1.0)
	sprite.modulate = Color(1.0, tint, tint, max_alpha)
