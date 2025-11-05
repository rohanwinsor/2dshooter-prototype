extends Area2D
class_name HurtboxComponent

signal damage_taken(amount: float)

func take_damage(amount: float) -> void:
	damage_taken.emit(amount)
