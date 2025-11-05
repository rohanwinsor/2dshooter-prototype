extends Area2D
class_name HitboxComponent

@export var damage: float = 10.0

signal hit_detected(hurtbox: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_damage(damage)
		hit_detected.emit(area)
