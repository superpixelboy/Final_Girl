extends Area3D
## Trigger to activate the happy face lock puzzle

@export var lock_path: NodePath
@export var interaction_prompt: String = "Press E to Examine"

var player_nearby: bool = false
var interaction_ui = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("Lock Trigger: Ready")
	
	# Find UI
	call_deferred("find_ui")

func find_ui():
	# Try to find UI via group first
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("Lock Trigger: Found UI via group")
		return
	
	# Fallback: try common paths
	var ui_paths = ["/root/Floor5/UI", "../UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			print("Lock Trigger: Found UI at ", path)
			return
	
	push_warning("Lock Trigger: No UI found - prompts won't show")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		show_prompt()
		print("Lock Trigger: Player nearby")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_prompt()
		print("Lock Trigger: Player left")

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		activate_lock()

func activate_lock():
	var lock = get_node(lock_path)
	if lock and lock.has_method("activate_lock"):
		print("Lock Trigger: Activating lock puzzle")
		hide_prompt()  # Hide prompt when entering lock view
		lock.activate_lock()

func show_prompt():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(interaction_prompt)

func hide_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
