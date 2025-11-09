extends Area3D

@export var examine_camera: Camera3D  # Camera positioned to look at the graphic novel
@export var examine_text: String = "I guess someone likes reading comics."

var player_nearby: bool = false
var is_examining: bool = false
var interaction_ui = null
var previous_camera: Camera3D = null

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
		print("GraphicNovel: Found UI")

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		if is_examining:
			exit_examination()
		elif player_nearby:
			enter_examination()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if not is_examining:
			show_interaction_prompt("Press E to examine Graphic Novel")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		if not is_examining:
			hide_interaction_prompt()

func enter_examination():
	if not examine_camera:
		print("GraphicNovel: No examine camera set!")
		return
	
	is_examining = true
	previous_camera = get_viewport().get_camera_3d()
	examine_camera.current = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("lock_movement"):
		player.lock_movement()
	
	show_interaction_prompt(examine_text + "\n\nPress E to stop examining")
	print("GraphicNovel: Entering examination mode")

func exit_examination():
	if not is_examining:
		return
	
	is_examining = false
	
	if previous_camera:
		previous_camera.current = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unlock_movement"):
		player.unlock_movement()
	
	if player_nearby:
		show_interaction_prompt("Press E to examine shelf.")
	else:
		hide_interaction_prompt()
	
	print("GraphicNovel: Exiting examination mode")

func show_interaction_prompt(text: String):
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
