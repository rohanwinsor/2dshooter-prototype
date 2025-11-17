extends RigidBody2D

var can_kill: bool = false
var kill_timer = 10
func _ready() -> void:
	add_to_group("Corpse")
	# Ensure corpse moves properly after impulse
	gravity_scale = 1.0
	mass = 1.0
	linear_damp = 0.0
	angular_damp = 0.0

	# Allow rotation for ragdoll effect
	lock_rotation = false

	# Make sure the body is not frozen
	freeze = false

func is_zero_velocity(v: Vector2, eps := 0.0001) -> bool:
	return abs(v.x) < eps and abs(v.y) < eps
	
func fade_and_free(duration := 0.2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free)
	
func _process(delta: float) -> void:
	if linear_velocity == Vector2.ZERO:
		can_kill = true
	elif can_kill:
		if is_zero_velocity(linear_velocity):
			fade_and_free()
