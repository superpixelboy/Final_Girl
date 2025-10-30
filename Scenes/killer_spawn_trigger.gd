extends Area3D

## Activates the killer when player enters this zone

@export var killer_path: NodePath  # Path to the Killer node
@export var one_time_trigger: bool = true  # Only trigger once

var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if has_triggered and one_time_trigger:
			return  # Already triggered
		
		trigger_killer()


func trigger_killer() -> void:
	if not killer_path:
		push_error("KillerSpawnTrigger: No killer path assigned!")
		return
	
	var killer = get_node(killer_path)
	if not killer:
		push_error("KillerSpawnTrigger: Killer not found at path!")
		return
	
	if killer.has_method("activate"):
		killer.activate()
		has_triggered = true
		print("KillerSpawnTrigger: Killer activated!")
		
		# Optional: Add a dramatic sound effect here later
		
		if one_time_trigger:
			# Disable the trigger after use
			monitoring = false
	else:
		push_error("KillerSpawnTrigger: Killer doesn't have activate() method!")
