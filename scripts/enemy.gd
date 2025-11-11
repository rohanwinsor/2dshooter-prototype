extends CharacterBody2D

const SPEED = 100.0
const HUNT_SPEED = 50.0
const ATTACK_RANGE = 200.0
const DETECTION_TIME = 2.0  # seconds player must stay visible

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var player_detection: RayCast2D = $PlayerDetection
@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var weapon: AnimatedSprite2D = $Weapon

var warning_shader: ShaderMaterial

@export var spriteColor: Color = Color()
@export var max_health: float = 100.0
@export var state = State.IDLE
@export var aim_tween_duration: float = 0.15

var detection_distance: int = 1000
var health: float
var camera: Camera2D
var is_player_detected: bool = false
var player_loc: Vector2
var previous_state: State = State.IDLE

var player_visible_time: float = 0.0  # Time player stays in view

enum State { IDLE, PATROL, HUNTING, ENGAGE }


func _ready():
	sprite_2d.modulate = spriteColor
	health = max_health
	if not camera:
		camera = get_viewport().get_camera_2d()
	
	# Setup warning flash shader
	var shader = load("res://shaders/enemy_warning_flash.gdshader")
	warning_shader = ShaderMaterial.new()
	warning_shader.shader = shader
	sprite_2d.material = warning_shader
	
	# Weapon starts hidden
	weapon.visible = true
	weapon.modulate.a = 0.0


func check_for_player(direction, delta) -> void:
	if visible_on_screen_notifier_2d.is_on_screen():
		player_detection.target_position = direction * detection_distance
		player_detection.force_raycast_update()
		if player_detection.is_colliding():
			var collider = player_detection.get_collider()
			if collider.is_in_group("Player"):
				is_player_detected = true
				player_loc = collider.global_position
				player_visible_time += delta
				return
	# If lost sight of player, reset timer
	is_player_detected = false
	player_visible_time = 0.0


func _physics_process(delta: float) -> void:
	var direction := Vector2(1, 0)
	if sprite_2d.flip_h:
		direction.x = -1

	if not is_on_floor():
		velocity += get_gravity() * delta

	check_for_player(direction, delta)
	
	# Update warning flash shader based on detection progress
	if state in [State.IDLE, State.PATROL] and is_player_detected:
		var flash_intensity = clamp(player_visible_time / DETECTION_TIME, 0.0, 1.0)
		warning_shader.set_shader_parameter("flash_intensity", flash_intensity)
	else:
		# Reset flash when not detecting or in other states
		warning_shader.set_shader_parameter("flash_intensity", 0.0)

	if player_visible_time >= DETECTION_TIME and state in [State.IDLE, State.PATROL]:
		change_state(State.HUNTING)

	match state:
		State.IDLE:
			handle_idle_state(delta)
		State.PATROL:
			handle_patrol_state(delta)
		State.HUNTING:
			handle_hunting_state(delta)
		State.ENGAGE:
			handle_engage_state(delta)

	move_and_slide()


# ---------- STATE MANAGEMENT ---------- #

func change_state(new_state: State) -> void:
	if state == new_state:
		return
	previous_state = state
	state = new_state
	on_enter_state(new_state)


func on_enter_state(new_state: State) -> void:
	match new_state:
		State.HUNTING:
			print("Raise weapon - prepare to engage player")
			# Reset warning flash when entering hunt state
			warning_shader.set_shader_parameter("flash_intensity", 0.0)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(weapon, "modulate:a", 1.0, aim_tween_duration)
			# TODO: Play weapon raise animation here

		State.ENGAGE:
			print("Player in range - prepare to shoot")
			# TODO: Trigger attack animation here

		State.IDLE, State.PATROL:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(weapon, "modulate:a", 0.0, aim_tween_duration)


# ---------- STATE HANDLERS ---------- #

func handle_idle_state(delta: float) -> void:
	velocity.x = 0


func handle_patrol_state(delta: float) -> void:
	# TODO: Implement patrol logic
	pass


func handle_hunting_state(delta: float) -> void:
	var dir = player_loc - global_position
	var distance = dir.length()

	if distance <= ATTACK_RANGE:
		change_state(State.ENGAGE)
		return

	dir = dir.normalized()
	velocity.x = dir.x * HUNT_SPEED
	sprite_2d.flip_h = dir.x < 0


func handle_engage_state(delta: float) -> void:
	print("Shoot player if visible")
	# TODO: Shooting logic goes here
	velocity.x = 0
	weapon.play("shoot")


# ---------- MISC ---------- #

func take_damage(damage: float) -> void:
	health -= damage
	print("Enemy took ", damage, " damage. Health: ", health, "/", max_health)
	if health <= 0:
		die()


func die() -> void:
	print("Enemy died!")
	queue_free()
