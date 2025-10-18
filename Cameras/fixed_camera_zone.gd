extends Area3D

@export var camera: Camera3D

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Make sure camera starts inactive
	if camera:
		camera.current = false

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and camera:
		camera.current = true

func _on_body_exited(body: Node3D) -> void:
	# Camera will be deactivated when player enters next zone
	pass
