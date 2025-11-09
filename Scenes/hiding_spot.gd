extends Area3D
class_name HidingSpot

## Hiding spot with mouse look and door crack UI effect

@export var hide_camera_path: NodePath
@export var door_crack_ui_path: NodePath 
@export var peek_angle_limit: float = 30.0
@export var peek_sensitivity: float = 0.15

var player_in_range: bool = false
var player_reference: CharacterBody3D = null
var hide_camera: Camera3D = null
var previous_camera: Camera3D = null
var is_occupied: bool = false
var hiding_player_reference: CharacterBody3D = null

# Mouse look
var base_camera_rotation: Vector3 = Vector3.ZERO
var current_peek_rotation: float = 0.0

# Door crack UI
@onready var door_crack_ui: CanvasLayer = null
var interaction_ui = null  

signal player_entered_hiding
signal player_exited_hiding


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Get the hide camera
	if hide_camera_path:
		hide_camera = get_node(hide_camera_path)
		if hide_camera:
			hide_camera.current = false
			base_camera_rotation = hide_camera.rotation
			print("HidingSpot: Base camera rotation stored: ", base_camera_rotation)
	
	# Get door crack UI via export
	if door_crack_ui_path:
		door_crack_ui = get_node(door_crack_ui_path)
		print("HidingSpot: Found door crack UI at: ", door_crack_ui_path)
	
	if not door_crack_ui:
		print("HidingSpot: Warning - No door crack UI found (optional)")
		
	call_deferred("find_interaction_ui")



func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		# Show prompt directly instead of going through player
		if interaction_ui and interaction_ui.has_method("show_prompt"):
			interaction_ui.show_prompt("Press E to Hide")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if not is_occupied:
			player_in_range = false
			# Hide prompt directly
			if interaction_ui and interaction_ui.has_method("hide_prompt"):
				interaction_ui.hide_prompt()
			player_reference = null


func try_hide_player() -> bool:
	"""Called by player when they press interact button"""
	if not player_in_range or is_occupied or not player_reference:
		return false
	
	if not hide_camera:
		push_error("HidingSpot: No hide camera assigned!")
		return false
	
	# Store the currently active camera
	previous_camera = get_viewport().get_camera_3d()
	
	# Store player reference
	hiding_player_reference = player_reference
	
	# Enter hiding
	is_occupied = true
	
	# Reset camera to base rotation
	hide_camera.rotation = base_camera_rotation
	current_peek_rotation = 0.0
	hide_camera.current = true
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Show door crack effect
	if door_crack_ui and door_crack_ui.has_method("show_crack"):
		door_crack_ui.show_crack()
		print("HidingSpot: Door crack shown")
	
	player_entered_hiding.emit()
	
	# Tell player they're hiding
	if player_reference.has_method("enter_hiding_state"):
		player_reference.enter_hiding_state(self)
	
	print("HidingSpot: Hiding (mouse captured, crack shown)")
	return true


func exit_hiding() -> void:
	"""Called when player wants to exit hiding spot"""
	if not is_occupied:
		return
	
	is_occupied = false
	
	# Release mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Hide door crack effect
	if door_crack_ui and door_crack_ui.has_method("hide_crack"):
		door_crack_ui.hide_crack()
		print("HidingSpot: Door crack hidden")
	
	# Reset camera
	if hide_camera:
		hide_camera.rotation = base_camera_rotation
		hide_camera.current = false
	
	# Restore previous camera
	if previous_camera and is_instance_valid(previous_camera):
		previous_camera.current = true
	
	# Tell player they're no longer hiding
	if hiding_player_reference and is_instance_valid(hiding_player_reference):
		if hiding_player_reference.has_method("exit_hiding_state"):
			hiding_player_reference.exit_hiding_state()
	
	hiding_player_reference = null
	current_peek_rotation = 0.0
	
	player_exited_hiding.emit()
	print("HidingSpot: Exited (mouse released, crack hidden)")


func _input(event: InputEvent) -> void:
	if not is_occupied or not hide_camera:
		return
	
	if event is InputEventMouseMotion:
		handle_mouse_peek(event)


func handle_mouse_peek(event: InputEventMouseMotion) -> void:
	"""Allow player to peek left/right with mouse"""
	var mouse_delta = -event.relative.x * peek_sensitivity
	current_peek_rotation += mouse_delta
	
	# Clamp rotation
	var max_rotation = deg_to_rad(peek_angle_limit)
	current_peek_rotation = clamp(current_peek_rotation, -max_rotation, max_rotation)
	
	# Apply relative to base rotation
	hide_camera.rotation.y = base_camera_rotation.y + current_peek_rotation
	
func find_interaction_ui():
	# Method 1: Check ui group
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("HidingSpot: Found UI via group: ", interaction_ui.name)
		return
	
	# Method 2: Try common paths
	var ui_paths = [
		"/root/Floor5/UI",
		"/root/patient_room/UI",
		"../UI",
		"../../UI"
	]
	
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			print("HidingSpot: Found UI via path: ", path)
			return
	
	print("WARNING HidingSpot: Could not find UI!")
