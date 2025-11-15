extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var door_action_region: Area2D = $DoorActionRegion
@onready var door_collision: Area2D = $DoorCollision

enum State {OPEN, CLOSE}
var state
var player_in_range: bool = false
func _ready() -> void:
	animated_sprite_2d.play("closed")
	state = State.CLOSE
	door_action_region.body_entered.connect(_body_entered)
	door_action_region.body_exited.connect(_body_exited)
	
	
func _body_entered(body: Node2D):
	print("Player Enterd", body.is_in_group("Player"))
	if body.is_in_group("Player") or body.is_in_group("Enemy"):
		player_in_range = true
		if state == State.CLOSE:
			body.can_move = false
			animated_sprite_2d.play("openning")
			await animated_sprite_2d.animation_finished
			animated_sprite_2d.play("open")
			state = State.OPEN
			body.can_move = true
		
	
func _body_exited(body: Node2D):
	print("Player Exited ::", body.is_in_group("Player"), "State ::", state)
	if body.is_in_group("Player") or body.is_in_group("Enemy"):
		player_in_range = false
		if state == State.OPEN:
			print("Player out")
			animated_sprite_2d.play("closing")
			await animated_sprite_2d.animation_finished
			animated_sprite_2d.play("close")
			state = State.CLOSE
			print("HERE?")


#func _process(delta: float) -> void:
	#if player_in_range and Input.is_action_just_pressed()
