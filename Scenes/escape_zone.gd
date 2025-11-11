extends Area3D

@export var escape_type: String = "elevator"
@export var next_floor_scene: String = ""
@export var show_victory_screen: bool = true
@export var required_item: String = "Elevator Key"  # Must have this to use elevator

var player_in_range: bool = false
var player_reference: CharacterBody3D = null
var has_escaped: bool = false
var interaction_ui = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		hide_prompt()
		player_reference = null

func update_prompt() -> void:
	if not player_reference:
		return
	
	var has_key = false
	if player_reference.has_method("get_held_item_name"):
		has_key = player_reference.get_held_item_name() == required_item
	
	if has_key:
		show_prompt("Press E to Use " + escape_type.capitalize())
	else:
		show_prompt("Locked. Requires " + required_item + ".")

func show_prompt(text: String) -> void:
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)

func hide_prompt() -> void:
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact") and not has_escaped:
		try_escape()

func try_escape() -> bool:
	"""Player attempts to escape"""
	if not player_in_range or not player_reference or has_escaped:
		return false
	
	# Check if player has the key
	var has_key = false
	if player_reference.has_method("get_held_item_name"):
		has_key = player_reference.get_held_item_name() == required_item
	
	if not has_key:
		print("Elevator: Player doesn't have key!")
		return false
	
	has_escaped = true
	
	print("EscapeZone: Player escaped via ", escape_type, "!")
	
	# Disable player movement
	if player_reference.has_method("set_can_move"):
		player_reference.can_move = false
	
	if show_victory_screen:
		show_escape_message()
	else:
		load_next_scene()
	
	return true

func show_escape_message() -> void:
	"""Show victory message then continue"""
	print("🎉 ESCAPED! YOU SURVIVED FLOOR 5! 🎉")
	
	await get_tree().create_timer(3.0).timeout
	
	load_next_scene()

func load_next_scene() -> void:
	"""Load next floor or show credits"""
	if next_floor_scene != "" and ResourceLoader.exists(next_floor_scene):
		get_tree().change_scene_to_file(next_floor_scene)
	else:
		print("No next scene defined - restarting current floor")
		get_tree().reload_current_scene()
