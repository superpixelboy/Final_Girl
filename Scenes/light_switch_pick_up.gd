extends Area3D

@export var item_name: String = "Light Panel"
@export var pickup_prompt: String = "Press E to pick up Light Panel"

var player_nearby: bool = false
var is_picked_up: bool = false
var interaction_ui = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 2
	collision_mask = 1
	
	print("LightPanel: Ready!")
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("LightPanel: Found UI via group")
		return
	
	var ui_paths = ["/root/Floor5/UI", "../UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			print("LightPanel: Found UI via path: ", path)
			return

func _process(_delta):
	if player_nearby and not is_picked_up and Input.is_action_just_pressed("interact"):
		pickup_panel()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_picked_up:
		player_nearby = true
		show_interaction_prompt()
		print("LightPanel: Player entered range")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_prompt()
		print("LightPanel: Player left range")

func pickup_panel():
	print("LightPanel: Pickup initiated!")
	is_picked_up = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("equip_item"):
		player.equip_item(item_name, self)
		player_nearby = false
		print("Light panel picked up!")
	
	hide_interaction_prompt()
	visible = false
	set_deferred("monitoring", false)

func show_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(pickup_prompt)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
