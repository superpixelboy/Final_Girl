extends Area3D

@export var killer_path: NodePath  # Path to the Killer node
@export var killer_spawn_position: Node3D  # Where to teleport killer
@export var killer_patrol_waypoints: Array[Node3D] = []  # Patrol path
@export var warning_sound: AudioStream  # Footsteps/creepy sound during VO
@export var killer_appear_sound: AudioStream  # Sound when killer actually spawns
@export var vo_text: String = "What's that?! Someone's coming!\nI've got a bad feeling about this.\nI've got to hide."
@export var vo_duration: float = 3.0
@export var required_item: String = "Elevator Key"  # Must have this item to trigger

var has_triggered: bool = false
var interaction_ui = null
var warning_player: AudioStreamPlayer = null
var appear_player: AudioStreamPlayer = null

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Create warning sound player
	warning_player = AudioStreamPlayer.new()
	add_child(warning_player)
	if warning_sound:
		warning_player.stream = warning_sound
	
	# Create killer appear sound player
	appear_player = AudioStreamPlayer.new()
	add_child(appear_player)
	if killer_appear_sound:
		appear_player.stream = killer_appear_sound
	
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]

func _on_body_entered(body):
	if body.is_in_group("player") and not has_triggered:
		# Check if player has the elevator key IN THEIR INVENTORY (not just equipped)
		if body.has_method("has_item"):
			if body.has_item(required_item):
				has_triggered = true
				trigger_killer_escape_sequence()
			else:
				print("EscapeSequence: Player doesn't have elevator key yet")
		else:
			# Fallback: check held item (old method)
			if body.has_method("get_held_item_name"):
				var held_item = body.get_held_item_name()
				if held_item == required_item:
					has_triggered = true
					trigger_killer_escape_sequence()
				else:
					print("EscapeSequence: Player doesn't have elevator key yet")
					
func trigger_killer_escape_sequence():
	print("EscapeSequence: TRIGGERED!")
	
	# Play warning sound immediately
	if warning_player and warning_sound:
		warning_player.play()
	
	# Show VO
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(vo_text)
		get_tree().create_timer(vo_duration).timeout.connect(func():
			if interaction_ui:
				interaction_ui.hide_prompt()
		)
	
	# Get the killer
	var killer = get_node(killer_path) if killer_path else null
	if not killer:
		push_error("EscapeSequence: No killer found!")
		return
	
	# Teleport killer to spawn position
	if killer_spawn_position:
		killer.global_position = killer_spawn_position.global_position
	
	# Set patrol waypoints if available
	if killer.has_method("set_patrol_waypoints") and killer_patrol_waypoints.size() > 0:
		killer.set_patrol_waypoints(killer_patrol_waypoints)
	
	# PLAY KILLER APPEAR SOUND
	if appear_player and killer_appear_sound:
		appear_player.play()
		print("EscapeSequence: Playing killer appear sound")
	
	# Activate the killer
	if killer.has_method("activate"):
		killer.activate()
	
	# Disable trigger
	monitoring = false
	print("EscapeSequence: Complete!")
