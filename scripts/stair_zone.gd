class_name Stairs
extends Area2D
enum TYPE {UP, DOWN}
@onready var marker_2d: Marker2D = $Marker2D

@export var type = TYPE.UP
@export var target_stair_zone: NodePath

func get_target_stair() -> Stairs:
	if target_stair_zone:
		return get_node(target_stair_zone) as Stairs
	return null

func _ready() -> void:
	add_to_group("Stair")
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
