extends Area3D

@export var closet_interior_position: Node3D  # Where player teleports TO (inside closet)
@export var hallway_exit_position: Node3D     # Where player teleports TO (when exiting)
@export var prompt_text: String = "Open Closet"
@export var exit_prompt_text: String = "Exit Closet"

var player_in_range: bool = false
var player_inside_closet: bool = false
var player_ref: CharacterBody3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_hide_prompt()

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		_handle_interaction()

func _handle_interaction() -> void:
	if not player_ref:
		return
	
	if player_inside_closet:
		# Exit closet - teleport back to hallway
		player_ref.global_position = hallway_exit_position.global_position
		player_inside_closet = false
		print("Player exited closet")
	else:
		# Enter closet - teleport inside
		player_ref.global_position = closet_interior_position.global_position
		player_inside_closet = true
		print("Player entered closet")
	
	_update_prompt()

func _update_prompt() -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		if player_inside_closet:
			ui.show_prompt(exit_prompt_text)
		else:
			ui.show_prompt(prompt_text)

func _hide_prompt() -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		ui.hide_prompt()
