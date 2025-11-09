extends Area2D

func _ready() -> void:
	# Connect signals to detect when player enters/exits the stair zone
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set collision layers
	collision_layer = 0  # This area doesn't exist on any layer
	collision_mask = 1   # Detects bodies on layer 1 (player)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_stair_zone"):
		body.enter_stair_zone(self)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_stair_zone"):
		body.exit_stair_zone(self)
