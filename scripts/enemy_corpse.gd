extends RigidBody2D


func _ready() -> void:
	# Ensure corpse moves properly after impulse
	gravity_scale = 1.0
	mass = 1.0
	linear_damp = 0.0
	angular_damp = 0.0

	# Allow rotation for ragdoll effect
	lock_rotation = false

	# Make sure the body is not frozen
	freeze = false
