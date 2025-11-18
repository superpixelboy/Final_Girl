extends Area3D

@export var item_name: String = "Light Panel"
@export_multiline var item_description: String = "An electrical panel cover. Looks like it belongs to the broken light switch."
@export var pickup_prompt: String = "Press E to examine Light Panel"

# EXAMINATION POSE - Adjust in inspector
@export_group("Examination Pose")
@export var exam_position: Vector3 = Vector3(0, 0, -0.5)
@export var exam_rotation: Vector3 = Vector3(0, 0, 0)
@export var exam_scale: float = 3.0

var player_nearby: bool = false
var is_picked_up: bool = false
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

func _process(_delta):
	if player_nearby and not is_picked_up:
		if Input.is_action_just_pressed("interact"):
			start_examination()

func start_examination():
	print("LightPanel: Starting examination")
	is_picked_up = true
	hide_interaction_prompt()
	
	var examiner = get_tree().get_first_node_in_group("item_examiner")
	if not examiner:
		print("ERROR: No item_examiner found!")
		return
	
	# Get the mesh child - MUST be named "LightPanelMesh"
	var mesh_node = get_node_or_null("LightPanelMesh")
	if mesh_node:
		print("Found LightPanelMesh, removing from pickup...")
		remove_child(mesh_node)
		
		examiner.start_examination(
			mesh_node, 
			item_name, 
			item_description,
			exam_position,
			exam_rotation,
			exam_scale
		)
	else:
		print("ERROR: No LightPanelMesh child found!")
	
	visible = false
	set_deferred("monitoring", false)

func _on_body_entered(body):
	if body.is_in_group("player") and not is_picked_up:
		player_nearby = true
		show_interaction_prompt()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(pickup_prompt)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
