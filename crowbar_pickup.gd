extends Area3D

# Crowbar/Bar pickup with working UI prompt

@export var item_name: String = "Crowbar"
@export var pickup_prompt: String = "Press E to pick up Crowbar"

var player_nearby: bool = false
var is_picked_up: bool = false

# Reference to UI
var interaction_ui = null

func _ready():
	# Connect to player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up collision layer (Layer 2 for interactables)
	collision_layer = 2
	collision_mask = 1  # Detects player on Layer 1
	
	print("Crowbar: Ready!")
	
	# Find UI - try multiple methods
	call_deferred("find_ui")

func find_ui():
	# Method 1: Check ui group
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("Crowbar: Found UI via group: ", interaction_ui.name)
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
			print("Crowbar: Found UI via path: ", path)
			return
	
	print("WARNING Crowbar: Could not find UI! Prompt won't show.")
	print("  Make sure your UI CanvasLayer is in the 'ui' group!")

func _process(_delta):
	# Check for interaction input when player is nearby
	if player_nearby and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			pickup_crowbar()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_picked_up:
		player_nearby = true
		show_interaction_prompt()
		print("Crowbar: Player entered range")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_prompt()
		print("Crowbar: Player left range")

func pickup_crowbar():
	print("Crowbar: Pickup initiated!")
	is_picked_up = true
	
	# Get reference to player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("equip_item"):
		# Find the visual mesh (CrowbarMesh child)
		var mesh_node = get_node_or_null("CrowbarMesh")
		
		if mesh_node:
			print("Crowbar: Found CrowbarMesh, sending to player")
			# Remove mesh from this Area3D
			remove_child(mesh_node)
			# Give mesh to player (not the Area3D!)
			player.equip_item(item_name, mesh_node)
		else:
			print("ERROR Crowbar: No CrowbarMesh found! Sending entire Area3D as fallback")
			# Fallback: send entire node
			player.equip_item(item_name, self)
	
	# Hide the interaction prompt
	hide_interaction_prompt()
	
	# Hide THIS pickup area (the mesh is already removed or moved)
	visible = false
	
	# Disable collision so player doesn't re-interact
	set_deferred("monitoring", false)

func show_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(pickup_prompt)
		print("Crowbar: Showing prompt via UI")
	else:
		# Fallback to console if no UI
		print("PROMPT: ", pickup_prompt)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
		print("Crowbar: Hiding prompt via UI")

# Called when used on the door
func use_item():
	print("Crowbar: Using to pry open door...")
	return true  # Successfully used
