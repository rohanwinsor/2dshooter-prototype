extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var sprite_2d: Sprite2D = $Sprite2D
const GRAVITY = 1000.0  # pixels/sec²
@export var spriteColor: Color = Color()
@export var max_health: float = 100.0

var health: float

func _ready():
	sprite_2d.modulate = spriteColor
	health = max_health

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func take_damage(damage: float) -> void:
	health -= damage
	print("Enemy took ", damage, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		die()

func die() -> void:
	print("Enemy died!")
	queue_free()
