"""
DEFINE ENEMY BEHAVIOR for 2D action platformer
stateDiagram-v2
    [*] --> PATROL
    [*] --> IDLE

    %% INITIAL ONLY (first time enemy detects or reacts)
    PATROL --> SUSPICION: Player visible initial delay 1s
    IDLE --> SUSPICION: Player visible initial delay 1s

    PATROL --> HUNTING: Gunshot heard initial delay 1s
    IDLE --> HUNTING: Gunshot heard initial delay 1s

    %% AFTER INITIAL DETECTION (no more delays)
    PATROL --> SUSPICION: Player visible no delay after first seen
    IDLE --> SUSPICION: Player visible no delay after first seen

    PATROL --> HUNTING: Gunshot heard no delay after first seen
    IDLE --> HUNTING: Gunshot heard no delay after first seen

    %% SUSPICION BRANCH
    SUSPICION --> HUNTING: No cover nearby hold 1s
    SUSPICION --> TAKE_COVER: Cover nearby hold 1s
    TAKE_COVER --> HUNTING: Fire warning shot

    %% HUNTING BEHAVIOR
    HUNTING --> SEARCHING: Player lost or gunshot location empty

    %% SEARCHING BEHAVIOR
    SEARCHING --> HUNTING: Player visible no delay
    SEARCHING --> PATROL: Search complete return to patrol
    SEARCHING --> IDLE: Search complete return to idle
"""
extends CharacterBody2D

@onready var obstacle_detection: RayCast2D = $ObstacleDetection
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var weapon: AnimatedSprite2D = $Weapon
@onready var weapon_vibe: AnimatedSprite2D = $WeaponVibe
@onready var timer: Timer = $Timer
@onready var player_detection: ShapeCast2D = $PlayerDetection

enum State {IDLE, PATROL, SUSPICION, TAKE_COVER, HUNTING, SEARCHING, ENGAGE}

#var state = State.IDLE if randi_range(0, 1) else State.PATROL
var state = State.PATROL
var can_move := true
var direction := Vector2(1, 0)
var patrol_speed := 100
var SPEED := 100
const SHOT_DISTANCE_REACT = 100_000
const REACT_2_PLAYER_NEAR_ENEMY_TIMEOUT = 50
var previous_state: State
var multipler: float
var target_position: Vector2
var react_2_player_near_enemy_timeout := REACT_2_PLAYER_NEAR_ENEMY_TIMEOUT
var has_enemy_seen_player := false
const NOT_SEEN_PLAYER_DELAY := 1.0
const SEEN_PLAYER_DELAY := NOT_SEEN_PLAYER_DELAY * 0.5
var detection_delay := NOT_SEEN_PLAYER_DELAY
var following_player := false
# --Stair Navigation--
var target_stair: Stairs
var DOWN_THRESHOLD = -10
var UP_THRESHOLD = 52
var player: Player


func _ready() -> void:
	timer.wait_time = 1.0
	timer.one_shot = true
	player = get_tree().get_first_node_in_group("Player")
	change_state(state)
	on_enter_state(state)
	scale = Vector2(1, 1)
	add_to_group("Enemy")
	for i in range(1, 33):
		obstacle_detection.set_collision_mask_value(i, i == 1)
	obstacle_detection.collide_with_bodies = true
	obstacle_detection.collide_with_areas = true

func flip():
	scale.x = scale.x * -1
	# obstacle_detection.scale.x = scale.x
	# direction.x = scale.x
	# weapon.flip_h = true if direction.x == 1 else false
	# weapon_vibe.flip_h = true if direction.x == 1 else false

func check_for_obstacle() -> bool:
	obstacle_detection.force_raycast_update()
	if obstacle_detection.is_colliding():
		return true
	return false

func _physics_process(delta: float) -> void:
	if can_move == false:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	check_for_player(delta)
	match state:
		State.IDLE:
			handle_idle_state(delta)
		State.PATROL:
			handle_patrol_state(delta)
		State.SEARCHING:
			handle_searching_state(delta)
	move_and_slide()


func handle_idle_state(_detla):
	velocity.x = 0

func handle_patrol_state(_detla):
	if check_for_obstacle():
		flip()
		direction = Vector2(-1 * direction.x, 0)
		velocity.x = 0
	velocity.x = direction.x * patrol_speed

func handle_searching_state(_delta):
	navigate_to_postion(target_position)

func change_state(new_state: State) -> void:
	if state == new_state:
		return
	on_exit_state(state)
	state = new_state
	on_enter_state(new_state)

func on_enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			enter_idle_state(new_state)
		State.PATROL:
			enter_patrol_state(new_state)
		State.SEARCHING:
			enter_searching_state(new_state)

func enter_idle_state(_to_state: State) -> void:
	weapon.modulate.a = 0
	weapon_vibe.modulate.a = 1
	velocity.x = 0

func enter_patrol_state(_to_state: State) -> void:
	weapon.modulate.a = 0
	weapon_vibe.modulate.a = 1

func enter_searching_state(_to_state: State) -> void:
	weapon.modulate.a = 1

func on_exit_state(old_state: State) -> void:
	match old_state:
		State.IDLE:
			exit_idle_state(old_state)
		State.PATROL:
			exit_patrol_state(old_state)


func exit_idle_state(_from_state: State) -> void:
	weapon_vibe.modulate.a = 0 # HIDE VIBE


func exit_patrol_state(_from_state: State) -> void:
	weapon_vibe.modulate.a = 0 # HIDE VIBE

func is_shot_near(_position):
	multipler = floor(abs(global_position.y - _position.y) / 100)
	multipler = 0.5 if multipler == 0 else multipler
	if (global_position.distance_squared_to(_position) * multipler) <= SHOT_DISTANCE_REACT:
		change_state(State.SEARCHING)
		target_position = _position

func check_for_player(delta):
	# DO A RAY CAST IN THE DIRECTION WE ARE FACING TO CHECK FOR PLAYER
	#player_detection.target_position = direction * detection_distance
	player_detection.force_shapecast_update()
	if player_detection.is_colliding():
		var collider = player_detection.get_collider(0)
		if collider.is_in_group("Player"):
			detection_delay -= delta
			print("detection_delay ::", detection_delay)
			if detection_delay <= 0:
				if player:
					target_position = player.global_position
				else:
					player = get_tree().get_first_node_in_group("Player")
					target_position = player.global_position
				change_state(State.SEARCHING)
	else:
		if has_enemy_seen_player:
			detection_delay = SEEN_PLAYER_DELAY
		else:
			detection_delay = NOT_SEEN_PLAYER_DELAY
#func player_near_us(delta):
	#var distance_2_player = global_position.distance_to(player.global_position)
	#if distance_2_player <= 50:
		#react_2_player_near_enemy_timeout -= delta
		#print(react_2_player_near_enemy_timeout)
		#if react_2_player_near_enemy_timeout <= 0:
			#change_state(State.IDLE)
			#react_2_player_near_enemy_timeout = REACT_2_PLAYER_NEAR_ENEMY_TIMEOUT
	#else:
		#react_2_player_near_enemy_timeout = REACT_2_PLAYER_NEAR_ENEMY_TIMEOUT

# Core Navigation Logic, take in wat position to go to and will take the player ter
func navigate_to_postion(postion):	
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
		else:
			velocity.x = 0
			return
	elif v_distance >= UP_THRESHOLD:
		var distance_2_marker = global_position.x - nearest_up_stairs.global_position.x
		direction.x = 1 if distance_2_marker <= 0 else -1
		if abs(distance_2_marker) <= 1:
			target_stair = nearest_up_stairs.get_target_stair()
			velocity.x = 0
		else:
			velocity.x = direction.x * SPEED
	elif v_distance <= DOWN_THRESHOLD:
		var distance_2_marker = global_position.x - nearest_down_stairs.global_position.x
		direction.x = 1 if distance_2_marker <= 0 else -1
		if abs(distance_2_marker) <= 1:
			target_stair = nearest_down_stairs.get_target_stair()
			velocity.x = 0
		else:
			velocity.x = direction.x * SPEED
	else:
		print("UNKNOWN")
		
# Navigation helper
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

## Stair Logics
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
