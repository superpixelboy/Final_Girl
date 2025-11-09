extends Area3D

@export var requires_item: String = "Light Panel"
@export var switch_panel_node: Node3D  # The panel that will rotate 180 degrees
@export var lights_to_activate: Array[Node3D] = []  # Drag lights here that should turn on

var player_nearby: bool = false
var is_fixed: bool = false
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
	if player_nearby and Input.is_action_just_pressed("interact"):
		interact_with_switch()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		update_interaction_prompt(body)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_prompt()

func update_interaction_prompt(player):
	if not is_fixed:
		var has_panel = player.get_held_item_name() == requires_item
		if has_panel:
			show_interaction_prompt("Press E to install Light Panel")
		else:
			show_interaction_prompt("Press E to examine Light Switch")

func interact_with_switch():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if not is_fixed:
		if player.get_held_item_name() == requires_item:
			install_panel(player)
		else:
			# Just examine - show broken message
			show_interaction_prompt("Not working. Looks like it needs a new front panel.")
			# Auto-hide after 2 seconds
			await get_tree().create_timer(2.0).timeout
			if player_nearby:
				update_interaction_prompt(player)

func install_panel(player):
	if player.has_method("unequip_item"):
		player.unequip_item()
	
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
	
	hide_interaction_prompt()

func show_interaction_prompt(text: String):
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
