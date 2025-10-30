extends Area3D

@export var camera: Camera3D

func _ready() -> void:
	# Debug info
	print("🎬 Camera zone ready: ", name)
	if not camera:
		push_error("❌ NO CAMERA ASSIGNED to zone: " + name)
	else:
		print("   ✅ Camera assigned: ", camera.name)
		print("   📍 Camera path: ", camera.get_path())
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Make sure camera starts inactive
	if camera:
		camera.current = false

func _on_body_entered(body: Node3D) -> void:
	print("🚶 Body entered zone '", name, "': ", body.name)
	
	# Use groups instead of name checking (more reliable!)
	if body.is_in_group("player"):
		if camera:
			print("📹 SWITCHING TO CAMERA: ", camera.name)
			camera.current = true
		else:
			print("   ❌ Camera not assigned to this zone!")
	else:
		print("   ℹ️  Not a player (missing 'player' group)")

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("👋 Player left zone: ", name)
	# Camera will be deactivated when player enters next zone
