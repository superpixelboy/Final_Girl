extends Area3D

@export var requires_item: String = "Light Panel"
@export var switch_panel_node: Node3D  # The panel that will rotate 180 degrees
@export var lights_to_activate: Array[Node3D] = []  # Drag lights here that should turn on
@export var examine_camera: Camera3D  # Camera positioned to zoom in on switch

var player_nearby: bool = false
var is_fixed: bool = false
var is_examining: bool = false
var previous_camera: Camera3D = null
var interaction_ui = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 2
	collision_mask = 1
	
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("LightSwitch: Found UI via group")
		return
	
	var ui_paths = ["/root/Floor5/UI", "../UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			print("LightSwitch: Found UI via path: ", path)
			return

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		if is_examining:
			exit_examination()
		elif player_nearby:
			interact_with_switch()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if not is_examining:
			update_interaction_prompt(body)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		if not is_examining:
			hide_interaction_prompt()

func update_interaction_prompt(player):
	if not is_fixed:
		var has_panel = player.has_item(requires_item)
		if has_panel:
			show_interaction_prompt("Press E to install Light Panel")
		else:
			show_interaction_prompt("Press E to examine Light Switch")
	else:
		# After it's fixed, can still examine
		show_interaction_prompt("Press E to examine Light Switch")

func interact_with_switch():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if not is_fixed:
		if player.has_item(requires_item):
			install_panel(player)
		else:
			# Enter examination mode to show broken switch up close
			enter_examination(player, false)
	else:
		# After fixed, just examine to admire the handiwork
		enter_examination(player, true)

func enter_examination(player, is_post_fix: bool):
	if not examine_camera:
		print("LightSwitch: No examine camera set!")
		# Fallback to old behavior
		var message = "Looks like the lights are on now." if is_post_fix else "Not working. Looks like it needs a new front panel."
		show_interaction_prompt(message)
		await get_tree().create_timer(2.0).timeout
		if player_nearby:
			update_interaction_prompt(player)
		return
	
	is_examining = true
	previous_camera = get_viewport().get_camera_3d()
	examine_camera.current = true
	
	if player.has_method("lock_movement"):
		player.lock_movement()
	
	# Different message depending on state
	var examine_text = ""
	if is_post_fix:
		examine_text = "Looks like the lights are on now.\n\nPress E to stop examining"
	else:
		examine_text = "Not working. Looks like it needs a new front panel.\n\nPress E to stop examining"
	
	show_interaction_prompt(examine_text)
	print("LightSwitch: Entering examination mode")

func exit_examination():
	if not is_examining:
		return
	
	is_examining = false
	
	if previous_camera:
		previous_camera.current = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unlock_movement"):
		player.unlock_movement()
	
	if player_nearby and player:
		update_interaction_prompt(player)
	else:
		hide_interaction_prompt()
	
	print("LightSwitch: Exiting examination mode")

func install_panel(player):
	if player.has_method("remove_from_inventory"):
		player.remove_from_inventory(requires_item)
	
	is_fixed = true
	print("LightSwitch: Panel installed! Rotating and activating lights...")
	
	# Rotate the panel 180 degrees to show the fixed side
	if switch_panel_node:
		switch_panel_node.rotation_degrees.y += 180
	
	# Turn on all the lights
	for light in lights_to_activate:
		if light:
			light.visible = true
			print("LightSwitch: Activated light: ", light.name)
	
	# Auto-examine after installation to show the fixed switch
	enter_examination(player, true)

func show_interaction_prompt(text: String):
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
