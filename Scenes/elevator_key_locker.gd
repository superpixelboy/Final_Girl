extends Node3D

@export var locked_cabinet_scene: Node3D  # Drag your locked cabinet here
@export var unlocked_cabinet_scene: Node3D  # Drag your unlocked cabinet here
@export var elevator_key_pickup: Area3D  # Drag the ElevatorKey_Pickup here

var is_unlocked: bool = false

func _ready():
	# Start with locked visible, unlocked hidden
	if locked_cabinet_scene:
		locked_cabinet_scene.visible = true
	
	if unlocked_cabinet_scene:
		unlocked_cabinet_scene.visible = false
	
	# Hide the key pickup until unlocked AND disable collision detection
	if elevator_key_pickup:
		elevator_key_pickup.visible = false
		elevator_key_pickup.monitoring = false
		elevator_key_pickup.monitorable = false
	
	print("Cabinet: Ready (locked state)")

func unlock():
	if is_unlocked:
		return
	
	is_unlocked = true
	print("Cabinet: UNLOCKING!")
	
	# Hide locked version
	if locked_cabinet_scene:
		locked_cabinet_scene.visible = false
	
	# Show unlocked version
	if unlocked_cabinet_scene:
		unlocked_cabinet_scene.visible = true
	
	# Show the key pickup AND enable collision detection!
	if elevator_key_pickup:
		elevator_key_pickup.visible = true
		elevator_key_pickup.monitoring = true
		elevator_key_pickup.monitorable = true
		print("Cabinet: Elevator key now visible and active")
	
	print("Cabinet: Now unlocked")
