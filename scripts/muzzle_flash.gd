extends GPUParticles2D

@onready var flash_light: PointLight2D = $FlashLight

func _ready() -> void:
	# Disable light initially
	if flash_light:
		flash_light.enabled = false
	
	# Connect to finished signal to clean up
	finished.connect(_on_finished)

func _process(_delta: float) -> void:
	# Enable light while emitting, disable when done
	if flash_light:
		flash_light.enabled = emitting

func _on_finished() -> void:
	# Clean up after particle effect finishes
	queue_free()
