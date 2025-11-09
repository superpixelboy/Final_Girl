extends Area3D

## Escape zone - player wins when entering this area

@export var escape_type: String = "elevator"  # "elevator", "door", "ambulance", etc.
@export var next_floor_scene: String = ""  # Path to next scene (e.g., "res://Floor4.tscn")
@export var show_victory_screen: bool = true  # Show "ESCAPED!" message

var player_in_range: bool = false
var player_reference: CharacterBody3D = null
var has_escaped: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		
		# Show prompt
		if player_reference.has_method("set_interaction_prompt"):
			player_reference.set_interaction_prompt(true, "Press E to Use " + escape_type.capitalize())


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		
		if player_reference and player_reference.has_method("set_interaction_prompt"):
			player_reference.set_interaction_prompt(false, "")
		
		player_reference = null


func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact") and not has_escaped:
		try_escape()


func try_escape() -> bool:
	"""Player attempts to escape"""
	if not player_in_range or not player_reference or has_escaped:
		return false
	
	has_escaped = true
	
	print("EscapeZone: Player escaped via ", escape_type, "!")
	
	# Disable player movement
	if player_reference.has_method("set_can_move"):
		player_reference.can_move = false
	
	if show_victory_screen:
		show_escape_message()
	else:
		# Go directly to next scene
		load_next_scene()
	
	return true


func show_escape_message() -> void:
	"""Show victory message then continue"""
	# For now: just print and wait
	print("🎉 ESCAPED! YOU SURVIVED FLOOR 5! 🎉")
	
	# Wait 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	load_next_scene()


func load_next_scene() -> void:
	"""Load next floor or show credits"""
	if next_floor_scene != "" and ResourceLoader.exists(next_floor_scene):
		get_tree().change_scene_to_file(next_floor_scene)
	else:
		# No next scene: restart current floor or quit
		print("No next scene defined - restarting current floor")
		get_tree().reload_current_scene()
