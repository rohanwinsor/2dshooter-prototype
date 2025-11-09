extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var sprite_2d: Sprite2D = $Sprite2D
const GRAVITY = 1000.0  # pixels/sec²
@export var spriteColor: Color = Color()

func _ready():
	sprite_2d.modulate = spriteColor

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
