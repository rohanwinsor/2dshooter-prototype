extends CharacterBody2D

const BULLET = preload("res://entities/bullet.tscn")

enum WeaponType { SHOTGUN, RIFLE }

@export var run_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 980.0

@export var aim_tween_duration: float = 0.15
@export var teleport_max_distance: float = 200.0
@export var teleport_time_scale: float = 0.1

# Weapon range
@export var max_weapon_range: float = 2000.0

# Shotgun properties
@export var shotgun_pellet_count: int = 8
@export var shotgun_spread_angle: float = 30.0
@export var shotgun_damage: float = 50.0

# Rifle properties
@export var rifle_pellet_count: int = 1
@export var rifle_spread_angle: float = 2.0
@export var rifle_damage: float = 120.0
@export var rifle_magazine_size: int = 1
@export var rifle_reload_time: float = 1.0  # Time between shots

var current_weapon: WeaponType = WeaponType.SHOTGUN
var rifle_ammo: int = 1
var is_reloading: bool = false
var can_use_stair: bool = false
var can_move = true
@onready var shotgun: AnimatedSprite2D = $WeaponRoot/ShootGun
@onready var rifle: AnimatedSprite2D = $WeaponRoot/Rifle
@onready var weapon_root: Node2D = $WeaponRoot
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var bullet_spawn_loc: Marker2D = $WeaponRoot/BulletSpawnLoc
@onready var muzzle_flash: PointLight2D = $PointLight2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_gun: AnimatedSprite2D

var teleport_aiming: bool = false
var teleport_indicator_vector: Vector2 = Vector2.ZERO
var teleport_target: Vector2 = Vector2.ZERO
var teleport_original_time_scale: float = 1.0

# Stair interaction
var using_stairs: bool = false
var landing_enabled: bool = true  # Landing platforms solid by default
var stair_check_distance: float = 32.0  # How close to stairs to activate

var is_aiming: bool = false
var gun_ready: bool = false
var can_shoot: bool = true
var shotgun_y_offset: float = -40.0  # From the shotgun's offset.y
var rifle_y_offset: float = -85.0  # From the rifle's offset.y

func _ready() -> void:
	add_to_group("Player")
	muzzle_flash.enabled = false
	weapon_root.visible = false
	
	# Setup shotgun
	shotgun.modulate.a = 0.0
	shotgun.scale = Vector2(0.04, 0.04)
	shotgun.play("idle")
	shotgun.animation_finished.connect(_on_gun_animation_finished)
	
	# Setup rifle
	rifle.modulate.a = 0.0
	rifle.scale = Vector2(0.10, 0.10)
	rifle.play("idle")
	rifle.animation_finished.connect(_on_gun_animation_finished)
	
	# Set initial weapon
	switch_weapon(WeaponType.SHOTGUN)


func _physics_process(delta: float) -> void:
	process_teleport_input()
	if can_move == false:
		return
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal movement
	var direction := Input.get_action_strength("right") - Input.get_action_strength("left")
	var current_speed = run_speed
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

	# Weapon switching
	if Input.is_action_just_pressed("weapon_1") and current_weapon != WeaponType.SHOTGUN:
		switch_weapon(WeaponType.SHOTGUN)
	elif Input.is_action_just_pressed("weapon_2") and current_weapon != WeaponType.RIFLE:
		switch_weapon(WeaponType.RIFLE)
	
	# Aim visibility and tween
	var is_running = Input.is_action_pressed("shift")
	var aiming = Input.is_action_pressed("aim") and not is_running
	
	if aiming and not is_aiming:
		# Start aiming - tween in
		is_aiming = true
		gun_ready = false
		weapon_root.visible = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(current_gun, "modulate:a", 1.0, aim_tween_duration)
		var target_scale = Vector2(0.06, 0.06) if current_weapon == WeaponType.SHOTGUN else Vector2(0.15, 0.15)
		tween.tween_property(current_gun, "scale", target_scale, aim_tween_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): gun_ready = true).set_delay(aim_tween_duration)
	
	elif (not aiming or is_running) and is_aiming:
		# Stop aiming - tween out
		is_aiming = false
		gun_ready = false
		var tween = create_tween().set_parallel(true)
		tween.tween_property(current_gun, "modulate:a", 0.0, aim_tween_duration)
		var target_scale = Vector2(0.04, 0.04) if current_weapon == WeaponType.SHOTGUN else Vector2(0.10, 0.10)
		tween.tween_property(current_gun, "scale", target_scale, aim_tween_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): weapon_root.visible = false).set_delay(aim_tween_duration)

	if is_aiming and not teleport_aiming:
		# Rotate weapon_root toward cursor so BulletSpawnLoc points at mouse
		var angle_to_mouse = weapon_root.global_position.angle_to_point(mouse_pos)
		weapon_root.rotation = angle_to_mouse
		
		# Flip weapon_root vertically when facing left
		weapon_root.scale.y = -1.0 if facing_left else 1.0

		# Fire
		if Input.is_action_just_pressed("shoot") and gun_ready and can_shoot and not is_reloading:
			if current_weapon == WeaponType.RIFLE and rifle_ammo <= 0:
				# Auto reload for rifle
				reload_rifle()
			else:
				shoot()
		
		# Manual reload for rifle
		if Input.is_action_just_pressed("reload") and current_weapon == WeaponType.RIFLE and rifle_ammo < rifle_magazine_size and not is_reloading:
			reload_rifle()

	# Keep gun on idle animation when not shooting or reloading
	if can_shoot and not is_reloading and current_gun.animation != "idle":
		current_gun.play("idle")
		
	if (Input.is_action_pressed("shift")) and can_use_stair:
		
		enable_stair_collision()
		disable_landing_collision()

func process_teleport_input() -> void:
	if Input.is_action_just_pressed("teleport_aim"):
		start_teleport_aim()

	if teleport_aiming:
		update_teleport_target()
		if Input.is_action_just_pressed("shoot"):
			execute_teleport()

	if Input.is_action_just_released("teleport_aim"):
		end_teleport_aim()

func start_teleport_aim() -> void:
	if teleport_aiming:
		return
	teleport_aiming = true
	teleport_original_time_scale = Engine.time_scale
	Engine.time_scale = teleport_time_scale
	update_teleport_target()

func update_teleport_target() -> void:
	var to_mouse = get_global_mouse_position() - global_position
	var length = to_mouse.length()
	if length > teleport_max_distance:
		to_mouse = to_mouse.normalized() * teleport_max_distance
	teleport_indicator_vector = to_mouse
	teleport_target = global_position + teleport_indicator_vector
	queue_redraw()

func end_teleport_aim() -> void:
	if not teleport_aiming:
		return
	teleport_aiming = false
	Engine.time_scale = teleport_original_time_scale
	teleport_indicator_vector = Vector2.ZERO
	teleport_target = global_position
	queue_redraw()

func execute_teleport() -> void:
	if teleport_indicator_vector.length() < 1.0:
		return
	var shape := collision_shape.shape
	if shape == null:
		return
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = collision_shape.global_transform.translated(teleport_indicator_vector)
	params.collision_mask = collision_mask
	params.collide_with_areas = false
	params.exclude = [self]
	var collisions := space_state.intersect_shape(params, 1)
	if collisions.is_empty():
		global_position += teleport_indicator_vector
		velocity = Vector2.ZERO
		end_teleport_aim()

func _draw() -> void:
	if not teleport_aiming or teleport_indicator_vector == Vector2.ZERO:
		return
	var color := Color(0.0, 0.497, 0.827, 0.85)
	var start := Vector2.ZERO
	var end := teleport_indicator_vector
	draw_line(start, end, color, 2.0)
	var dir := end.normalized()
	var head_length := 12.0
	var head_half_width := 6.0
	var tip := end
	var base := end - dir * head_length
	var offset := dir.orthogonal() * head_half_width
	draw_polygon([tip, base + offset, base - offset], [color, color, color])

func switch_weapon(weapon: WeaponType) -> void:
	current_weapon = weapon
	
	# Hide all weapons
	shotgun.visible = false
	rifle.visible = false
	
	# Show and setup current weapon
	if current_weapon == WeaponType.SHOTGUN:
		current_gun = shotgun
		shotgun.visible = true
		
	else:  # RIFLE
		current_gun = rifle
		rifle.visible = true
		rifle_ammo = rifle_magazine_size
		
	
	# Reset animation state
	current_gun.play("idle")
	can_shoot = true
	is_reloading = false

func shoot() -> void:
	# Play shoot animation
	can_shoot = false
	current_gun.play("shoot")
	
	# Trigger muzzle flash
	muzzle_flash.enabled = true
	muzzle_flash.energy = randf_range(2.5, 3.5)
	get_tree().create_timer(0.08).timeout.connect(func(): muzzle_flash.enabled = false)
	
	var shake_intensity = 10.0 if current_weapon == WeaponType.SHOTGUN else 6.0
	shake_camera(shake_intensity * 10, 0.08)

	# Calculate base angle toward cursor
	var mouse_pos = get_global_mouse_position()
	var aim_angle = weapon_root.global_position.angle_to_point(mouse_pos)
	var aim_direction = Vector2.RIGHT.rotated(aim_angle)

	# Get reference for bullet placement
	var scene_root = get_tree().current_scene
	var space_state = get_world_2d().direct_space_state

	# Get weapon-specific properties
	var pellet_count = shotgun_pellet_count if current_weapon == WeaponType.SHOTGUN else rifle_pellet_count
	var spread_angle = shotgun_spread_angle if current_weapon == WeaponType.SHOTGUN else rifle_spread_angle
	var bullet_damage = shotgun_damage if current_weapon == WeaponType.SHOTGUN else rifle_damage
	
	# Decrease rifle ammo
	if current_weapon == WeaponType.RIFLE:
		rifle_ammo -= 1
		

	# Fire pellets (hitscan + visual tracers)
	for i in range(pellet_count):
		# Calculate spread for this pellet
		var spread = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
		var angle = aim_angle + deg_to_rad(spread)
		var direction = Vector2.RIGHT.rotated(angle)
		
		# --- INSTANT HITSCAN RAYCAST ---
		var ray_start = bullet_spawn_loc.global_position
		var ray_end = ray_start + direction * max_weapon_range
		
		# Create query that checks walls (layer 1) and enemies (layer 2)
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = 17  # Binary 10001 = layers 1 and 5
		var exclude_nodes: Array = [self]
		for c in get_tree().get_nodes_in_group("Corpse"):
			exclude_nodes.append(c)
		query.exclude = exclude_nodes
		
		var result = space_state.intersect_ray(query)
		var hit_position = ray_end  # Default to max range
		var actual_bullet_distance = ray_start.distance_to(hit_position)
		
		if result:
			hit_position = result.position
			var collider = result.collider
			
			# Apply damage instantly if hit an enemy
			if collider.has_method("take_damage"):
				var distance_to_target = ray_start.distance_to(hit_position)
				collider.take_damage(bullet_damage, direction, distance_to_target)
		
		# Check for near misses on all enemies
		for enemy in get_tree().get_nodes_in_group("Enemy"):
			if enemy.has_method("is_bullet_near"):
				if enemy.is_bullet_near(ray_start, direction, actual_bullet_distance, 50.0):
					# Bullet passed near this enemy - trigger alert/suppression
					if enemy.has_method("on_bullet_near"):
						enemy.on_bullet_near()
		
		# --- SPAWN VISUAL BULLET TRACER ---
		var bullet = BULLET.instantiate()
		scene_root.add_child(bullet)
		bullet.global_position = ray_start
		bullet.global_rotation = angle
		bullet.direction = direction
		bullet.damage = 0.0  # Damage already applied by hitscan
		
		# Calculate lifetime based on distance to hit
		var distance_to_hit = ray_start.distance_to(hit_position)
		bullet.firing_distance = distance_to_hit
		bullet.lifetime = min(distance_to_hit / bullet.speed + 0.1, 2.0)
	
	# Auto-reload rifle if empty
	if current_weapon == WeaponType.RIFLE and rifle_ammo <= 0:
		get_tree().create_timer(0.5).timeout.connect(reload_rifle)

func reload_rifle() -> void:
	if is_reloading:
		return
		
	is_reloading = true
	can_shoot = false
	
	
	# Wait for reload time
	await get_tree().create_timer(rifle_reload_time).timeout
	
	rifle_ammo = rifle_magazine_size
	is_reloading = false
	can_shoot = true
	

func _on_gun_animation_finished() -> void:
	if current_gun.animation == "shoot":
		can_shoot = true
		if not is_reloading:
			current_gun.play("idle")

# Check if player is near stairs using raycasts
func is_near_stairs() -> bool:
	return true

func enable_stair_collision() -> void:
	if not using_stairs:
		set_collision_mask_value(2, true)   # Enable collision with Layer 2 (stairs)
		using_stairs = true
		

func disable_stair_collision() -> void:
	if using_stairs:
		set_collision_mask_value(2, false)  # Disable collision with Layer 2 (stairs)
		using_stairs = false
		

func enable_landing_collision() -> void:
	if not landing_enabled:
		set_collision_mask_value(3, true)   # Enable collision with Layer 3 (landing platforms)
		landing_enabled = true
		

func disable_landing_collision() -> void:
	if landing_enabled:
		set_collision_mask_value(3, false)  # Disable collision with Layer 3 (landing platforms)
		landing_enabled = false
		



# Called by StairZone when player enters
func enter_stair_zone(zone: Area2D) -> void:
	
	can_use_stair = true
	if not (Input.is_action_pressed("shift")):
		# if the player is not pressing the up or down button we can disable the stairs
		enable_landing_collision()
		disable_stair_collision()
		

# Called by StairZone when player enters
func exit_stair_zone(zone: Area2D) -> void:
	
	can_use_stair = false
		
func shake_camera(intensity: float = 6.0, duration: float = 0.08) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var original := cam.offset
	var t := create_tween()
	t.tween_property(cam, "offset", original + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(cam, "offset", original, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
