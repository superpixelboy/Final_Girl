extends Area3D

@export var closet_interior_position: Node3D  # Where player teleports TO

var player_in_range: bool = false
var player_ref: CharacterBody3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		_show_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_hide_prompt()

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		_enter_closet()

func _enter_closet() -> void:
	if player_ref and closet_interior_position:
		player_ref.global_position = closet_interior_position.global_position
		print("Player entered closet")

func _show_prompt() -> void:
	var ui = get_tree().get_first_node_in_group("interaction_ui")
	if ui:
		ui.show_prompt("Open Closet")

func _hide_prompt() -> void:
	var ui = get_tree().get_first_node_in_group("interaction_ui")
	if ui:
		ui.hide_prompt()
