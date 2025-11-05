extends CharacterBody2D

const MUZZLE_FLASH = preload("res://effects/muzzle_flash.tscn")
const BULLET = preload("res://entities/bullet.tscn")

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 980.0

@export var aim_tween_duration: float = 0.15

@export var pellet_count: int = 8
@export var spread_angle: float = 30.0

@onready var gun: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_sprite: Sprite2D = $Sprite2D
@onready var muzzle_flash_marker: Marker2D = $AnimatedSprite2D/MuzzleFlash
@onready var shoot_timer: Timer = $ShootTimer

var is_aiming: bool = false
var gun_ready: bool = false
var can_shoot: bool = true
var original_gun_y_offset: float = -40.0  # From the scene's offset.y

func _ready() -> void:
	gun.visible = false
	gun.modulate.a = 0.0
	gun.scale = Vector2(0.04, 0.04)
	gun.play("idle")
	gun.animation_finished.connect(_on_gun_animation_finished)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal movement
	var direction := Input.get_action_strength("right") - Input.get_action_strength("left")
	var current_speed = run_speed if Input.is_action_pressed("shift") else walk_speed
	velocity.x = direction * current_speed
	
	## Jump
	#if is_on_floor() and Input.is_action_just_pressed("jump"):
		#velocity.y = jump_velocity

	move_and_slide()
	
	# Gun aiming and rotation
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = (mouse_pos - global_position).normalized()

	# Sprite facing
	var facing_left = direction_to_mouse.x < 0
	player_sprite.flip_h = facing_left
	gun.flip_v = facing_left

	# Aim visibility and tween
	var is_running = Input.is_action_pressed("shift")
	var aiming = Input.is_action_pressed("aim") and not is_running
	
	if aiming and not is_aiming:
		# Start aiming - tween in
		is_aiming = true
		gun_ready = false
		gun.visible = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(gun, "modulate:a", 1.0, aim_tween_duration)
		tween.tween_property(gun, "scale", Vector2(0.06, 0.06), aim_tween_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): gun_ready = true).set_delay(aim_tween_duration)
	
	elif (not aiming or is_running) and is_aiming:
		# Stop aiming - tween out
		is_aiming = false
		gun_ready = false
		var tween = create_tween().set_parallel(true)
		tween.tween_property(gun, "modulate:a", 0.0, aim_tween_duration)
		tween.tween_property(gun, "scale", Vector2(0.04, 0.04), aim_tween_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): gun.visible = false).set_delay(aim_tween_duration)

	if is_aiming:
		# Rotate gun toward cursor from gun's position
		var angle_to_mouse = gun.global_position.angle_to_point(mouse_pos)
		gun.rotation = angle_to_mouse

		# Position alignment (avoid inversion drift)
		gun.position.x = abs(gun.position.x) * (-1 if facing_left else 1)
		
		# Adjust offset.y when flipped to compensate for vertical flip
		# When flip_v is true, the offset needs to be inverted
		gun.offset.y = -original_gun_y_offset if facing_left else original_gun_y_offset

		# Fire
		if Input.is_action_just_pressed("shoot") and shoot_timer.is_stopped() and gun_ready and can_shoot:
			shoot()

	# Keep gun on idle animation when not shooting
	if can_shoot and gun.animation != "idle":
		gun.play("idle")

func shoot() -> void:
	# Play shoot animation
	can_shoot = false
	gun.play("shoot")

	# Muzzle flash
	var flash = MUZZLE_FLASH.instantiate()
	muzzle_flash_marker.add_child(flash)
	flash.emitting = true

	# Calculate base angle toward cursor
	var mouse_pos = get_global_mouse_position()
	var aim_angle = muzzle_flash_marker.global_position.angle_to_point(mouse_pos)

	# Get reference for bullet placement
	var scene_root = get_tree().current_scene

	# Fire pellets
	for i in range(pellet_count):
		var bullet = BULLET.instantiate()
		scene_root.add_child(bullet)
		bullet.global_position = muzzle_flash_marker.global_position

		# Evenly distributed random spread
		var spread = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
		var angle = aim_angle + deg_to_rad(spread)
		bullet.global_rotation = angle
		bullet.direction = Vector2.RIGHT.rotated(angle)

	# Cooldown
	shoot_timer.start()
	print("Bang!")

func _on_gun_animation_finished() -> void:
	if gun.animation == "shoot":
		can_shoot = true
		gun.play("idle")
