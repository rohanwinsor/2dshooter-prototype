extends CharacterBody2D

const SPEED = 100.0
const HUNT_SPEED = 50.0
const ATTACK_RANGE = 20.0
const DETECTION_TIME = 2.0  # seconds player must stay visible

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var player_detection: RayCast2D = $PlayerDetection
@onready var obstacle_detection: RayCast2D = $ObstacleDetection
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
var cool_down_not_seen_player = 4
var player_visible_time: float = 0.0  # Time player stays in view

enum State { IDLE, PATROL, HUNTING, ENGAGE }


# --- Patrol parameters ---
@export var patrol_distance: float = 10000.0
@export var patrol_speed: float = 40.0
@export var patrol_cycles: int = 3

# --- Patrol state tracking ---
var patrol_start_pos: Vector2
var patrol_direction: int = 1

# --Stair Navigation--
var target_stair: Stairs
var DOWN_THRESHOLD = -10
var UP_THRESHOLD = 52

func _ready():
	# Only collide with world layer 1 (TileSet's physics_layer_0)
	for i in range(1, 33):
		obstacle_detection.set_collision_mask_value(i, i == 1)
	obstacle_detection.collide_with_bodies = true
	obstacle_detection.collide_with_areas = false
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

func check_for_obstacle(direction: Vector2) -> bool:
	if visible_on_screen_notifier_2d.is_on_screen():
		obstacle_detection.target_position = direction * 40
		obstacle_detection.force_raycast_update()
		if obstacle_detection.is_colliding():
			return true
	return false
			
	

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
				cool_down_not_seen_player = 4
				return
	# If lost sight of player, reset timer
	cool_down_not_seen_player = max(0, cool_down_not_seen_player - delta)
	is_player_detected = false
	player_visible_time = 0.0


func _physics_process(delta: float) -> void:
	var direction := Vector2(1, 0)
	if sprite_2d.flip_h:
		direction.x = -1

	if not is_on_floor():
		velocity += get_gravity() * delta

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player_loc = player.global_position
	#check_for_player(direction, delta)
	#check_for_obstacle(direction)
	navigate_to_postion(player_loc, delta)
	if false:
	# Update warning flash shader based on detection progress
		if state in [State.IDLE, State.PATROL] and is_player_detected:
			var flash_intensity = clamp(player_visible_time / DETECTION_TIME, 0.0, 1.0)
			warning_shader.set_shader_parameter("flash_intensity", flash_intensity)
		else:
			# Reset flash when not detecting or in other states
			warning_shader.set_shader_parameter("flash_intensity", 0.0)

		if player_visible_time >= DETECTION_TIME and state in [State.IDLE, State.PATROL]:
			change_state(State.HUNTING)
		if cool_down_not_seen_player == 0:
			change_state(State.PATROL)
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
	on_enter_state(new_state, previous_state)


func on_enter_state(new_state: State, previous_state: State) -> void:
	match new_state:
		State.PATROL:
			if previous_state == State.HUNTING:
				velocity.x = 0
				if sprite_2d.flip_h == true:
					sprite_2d.flip_h = false
				else:
					sprite_2d.flip_h = true
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
	velocity.x = patrol_direction * patrol_speed
	sprite_2d.flip_h = patrol_direction < 0

	var distance_from_start = abs(global_position.x - patrol_start_pos.x)
	if distance_from_start >= patrol_distance:
		patrol_direction *= -1
		patrol_start_pos.x = global_position.x
	print("Going to change dir", check_for_obstacle(Vector2(patrol_direction, 0)))
	print(Vector2(patrol_direction, 0))
	if check_for_obstacle(Vector2(patrol_direction, 0)):
		patrol_direction *= -1
		patrol_start_pos.x = global_position.x


func handle_hunting_state(delta: float) -> void:
	var dir = player_loc - global_position
	var distance = dir.length()

	if distance <= ATTACK_RANGE and is_player_detected:
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
func find_nearest_stairs():
	
	var stairs = get_tree().get_nodes_in_group("Stair")
	var nearest_up_stairs = null
	var nearest_down_stairs = null
	for stair in stairs:
		if stair.type == stair.TYPE.UP:
			if nearest_up_stairs == null:
				nearest_up_stairs = stair
			if stair.global_position.distance_to(global_position) < nearest_up_stairs.global_position.distance_to(global_position):
				nearest_up_stairs = stair
		if stair.type == stair.TYPE.DOWN:
			if nearest_down_stairs == null:
				nearest_down_stairs = stair
			if stair.global_position.distance_to(global_position) < nearest_down_stairs.global_position.distance_to(global_position):
				nearest_down_stairs = stair
	return [nearest_up_stairs, nearest_down_stairs]

func navigate_to_postion(postion, delta):	
	var result = find_nearest_stairs()
	var nearest_up_stairs = result[0]
	var nearest_down_stairs = result[1]
	var h_distance = global_position.x - postion.x
	var v_distance = global_position.y - postion.y
	var distance = 1 if h_distance <= 0 else -1
	if target_stair:
		use_stair()
		h_distance = global_position.x - target_stair.marker_2d.global_position.x
		distance = 1 if h_distance <= 0 else -1
		velocity.x = distance * SPEED
		if abs(h_distance) <= 10:
			stop_using_stair()
			target_stair = null
			velocity.x = 0
	elif DOWN_THRESHOLD <= v_distance and v_distance <= UP_THRESHOLD:
		# Player Same Level
		if abs(h_distance) >= 50:
			velocity.x = distance * SPEED
			sprite_2d.flip_h = distance < 0
		else:
			velocity.x = 0
			return
	elif v_distance >= UP_THRESHOLD:
		var distance_2_marker = global_position.x - nearest_up_stairs.global_position.x
		var direction = 1 if distance_2_marker <= 0 else -1
		if abs(distance_2_marker) <= 1:
				target_stair = nearest_up_stairs.get_target_stair()
				velocity.x = 0
		else:
			velocity.x = direction * SPEED
	elif v_distance <= DOWN_THRESHOLD:
		var distance_2_marker = global_position.x - nearest_down_stairs.global_position.x
		var direction = 1 if distance_2_marker <= 0 else -1
		if abs(distance_2_marker) <= 1:
				target_stair = nearest_down_stairs.get_target_stair()
				velocity.x = 0
		else:
			velocity.x = direction * SPEED
	else:
		print("Player Unknown")
# ---------- MISC ---------- #

func take_damage(damage: float) -> void:
	health -= damage
	print("Enemy took ", damage, " damage. Health: ", health, "/", max_health)
	if health <= 0:
		die()


func die() -> void:
	print("Enemy died!")
	queue_free()


func use_stair() -> void:
	enable_stair_collision()
	disable_landing_collision()
	
func stop_using_stair() -> void:
	disable_stair_collision()
	enable_landing_collision()
	
func enable_stair_collision() -> void:
	set_collision_mask_value(2, true)   # Enable collision with Layer 2 (stairs)

func disable_stair_collision() -> void:
	set_collision_mask_value(2, false)  # Disable collision with Layer 2 (stairs)

func enable_landing_collision() -> void:
	set_collision_mask_value(3, true)   # Enable collision with Layer 3 (landing platforms)

func disable_landing_collision() -> void:
	set_collision_mask_value(3, false)  # Disable collision with Layer 3 (landing platforms)
