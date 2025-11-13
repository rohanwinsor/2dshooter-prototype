extends Area2D

# Visual tracer properties
@export var speed: float = 8000.0
@export var lifetime: float = 2.0
@export var damage: float = 10.0

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var has_dealt_damage: bool = false  # Prevent multiple damage applications

func _ready() -> void:
	# Auto-despawn after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect overlap signals for backup collision detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return  # Wait until initialized
	
	# Move bullet visually
	velocity = direction * speed
	var movement = velocity * delta
	
	# Check for wall collision (layer 1) using short raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + movement)
	query.collision_mask = 1  # Only walls
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit wall, stop at impact point
		global_position = result.position
		explode()
		return
	
	# Move bullet
	position += movement

# Backup collision via Area2D overlap (for enemies on layer 2)
func _on_body_entered(body: Node2D) -> void:
	if has_dealt_damage:
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		has_dealt_damage = true
		explode()

func _on_area_entered(area: Area2D) -> void:
	if has_dealt_damage:
		return
	
	if area.has_method("take_damage"):
		area.take_damage(damage)
		has_dealt_damage = true
		explode()

func explode() -> void:
	# TODO: Add particle effect or sprite animation
	queue_free()
