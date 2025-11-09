extends Area2D

@export var speed: float = 8000.0
@export var lifetime: float = 5.0
@export var damage: float = 10.0

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return  # wait until initialized
	
	velocity = direction * speed
	var movement = velocity * delta
	
	# Perform raycast from current position to next position
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + movement)
	
	# Check for bodies (walls, static objects) - collision layer 1
	query.collision_mask = 1
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit a solid body
		position = to_local(result.position)
		explode()
		return
	
	# Check for enemies - collision layer 2
	query.collision_mask = 2
	result = space_state.intersect_ray(query)
	
	if result:
		# Hit an enemy
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
			position = to_local(result.position)
			explode()
			return
	
	# No collision, move normally
	position += movement

func explode() -> void:
	queue_free()
