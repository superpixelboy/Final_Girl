extends CharacterBody3D
class_name Killer

## The relentless slasher enemy
## Patrols slowly, chases when player is spotted

enum State { IDLE, PATROL, CHASE }

# Movement speeds
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 4.0
@export var rotation_speed: float = 3.0

# Detection
@export var detection_range: float = 10.0
@export var line_of_sight_enabled: bool = true
@export var catch_range: float = 1.5  # ← ADD THIS - How close to grab player

# Patrol
@export var patrol_points_path: NodePath
@export var start_active: bool = false  # ← ADD THIS LINED THIS LINE!

var current_state: State = State.IDLE
var target_player: CharacterBody3D = null
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var anim_player: AnimationPlayer = $KillerTest/AnimationPlayer 

func _ready() -> void:
	# Setup navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	# Connect detection
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	
	# Load patrol points if assigned
	if patrol_points_path:
		load_patrol_points()
	
	# Check if we should start inactive
	if not start_active:
		set_physics_process(false)  # Disable AI
		visible = false  # Hide the killer
		print("Killer: Spawned but INACTIVE (waiting for trigger)")
		return
	
	# Start in appropriate state
	current_state = State.PATROL if not patrol_points.is_empty() else State.IDLE
	
	if current_state == State.PATROL:
		nav_agent.target_position = patrol_points[0]
		print("Killer: Starting patrol with ", patrol_points.size(), " points")
	else:
		print("Killer: Starting in IDLE (no patrol points)")

func activate() -> void:
	"""Called by trigger zone to activate the killer"""
	print("Killer: ACTIVATED! Beginning hunt...")
	visible = true
	set_physics_process(true)
	
	# Start patrolling if we have points, otherwise idle
	if not patrol_points.is_empty():
		current_state = State.PATROL
		current_patrol_index = 0
		nav_agent.target_position = patrol_points[0]
		print("Killer: Starting patrol with ", patrol_points.size(), " points")
	else:
		current_state = State.IDLE
		print("Killer: Activated in IDLE (no patrol points yet)")
		
func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.PATROL:
			process_patrol(delta)
		State.CHASE:
			process_chase(delta)


func process_idle(_delta: float) -> void:
	"""Stand still, watch for player"""
	if anim_player and anim_player.current_animation != "Idle":
		anim_player.play("Idle")

func set_patrol_waypoints(waypoints: Array[Node3D]) -> void:
	"""Set new patrol waypoints from an array of Node3D markers"""
	patrol_points.clear()
	
	for waypoint in waypoints:
		if waypoint:
			patrol_points.append(waypoint.global_position)
			print("Killer: Added waypoint at ", waypoint.global_position)
	
	print("Killer: Set ", patrol_points.size(), " patrol waypoints")
	
	# Start patrolling if we're not already chasing
	if current_state != State.CHASE and not patrol_points.is_empty():
		current_state = State.PATROL
		current_patrol_index = 0
		nav_agent.target_position = patrol_points[0]
		print("Killer: Starting patrol from first waypoint")

func load_patrol_points() -> void:
	"""Load patrol waypoints from Marker3D children"""
	var patrol_container = get_node(patrol_points_path)
	if not patrol_container:
		push_error("Killer: Patrol points path invalid!")
		return
	
	patrol_points.clear()
	for child in patrol_container.get_children():
		if child is Marker3D or child is Node3D:
			patrol_points.append(child.global_position)
			print("Killer: Added patrol point at ", child.global_position)
	
	print("Killer: Loaded ", patrol_points.size(), " patrol points")

func process_patrol(delta: float) -> void:
	"""Walk between patrol points"""
	if anim_player and anim_player.current_animation != "Patrol":
		anim_player.play("Patrol")
	
	if patrol_points.is_empty():
		current_state = State.IDLE
		return
	
	# Simple patrol: go to waypoints in order
	if nav_agent.is_navigation_finished():
		# Move to next patrol point
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		nav_agent.target_position = patrol_points[current_patrol_index]
	
	move_toward_target(patrol_speed, delta)


func process_chase(delta: float) -> void:
	"""Chase the player relentlessly"""
	if anim_player and anim_player.current_animation != "Chase":
		anim_player.play("Chase")
	
	if not target_player or not is_instance_valid(target_player):
		lose_player()
		return
	
	# Update target position every frame
	nav_agent.target_position = target_player.global_position
	
	# Check if close enough to catch player
	var distance = global_position.distance_to(target_player.global_position)
	if distance <= catch_range:
		attempt_catch()  # ← ADD THIS
		return
	
	# Check if player is still visible
	if line_of_sight_enabled and not has_line_of_sight_to_player():
		print("Killer: Lost sight of player")
		lose_player()
		return
	
	# Check distance - if player left the detection bubble
	if distance > detection_range:
		print("Killer: Player too far, giving up chase")
		lose_player()
		return
	
	move_toward_target(chase_speed, delta)

func attempt_catch() -> void:
	"""Try to catch the player"""
	if not target_player:
		return
	
	print("Killer: CAUGHT PLAYER!")
	
	# For now: instant death (later we'll check for defensive items)
	kill_player()


func kill_player() -> void:
	"""Player dies - game over"""
	print("Killer: PLAYER KILLED!")
	
	# Stop chasing
	current_state = State.IDLE
	if anim_player:
		anim_player.play("Idle")
	
	# Tell player they died
	if target_player and target_player.has_method("die"):
		target_player.die()
	else:
		# Fallback: reload scene after delay
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func move_toward_target(speed: float, delta: float) -> void:
	"""Move along navigation path"""
	if nav_agent.is_navigation_finished():
		return
	
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Rotate to face direction
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	# Move
	velocity = direction * speed
	move_and_slide()


func has_line_of_sight_to_player(player: CharacterBody3D = null) -> bool:
	"""Raycast to check if player is visible"""
	var check_target = player if player != null else target_player
	
	if not check_target:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 1.0, 0)  # Eye level
	var to = check_target.global_position + Vector3(0, 1.0, 0)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return true  # No obstruction
	
	# Check if we hit the player
	return result.collider.is_in_group("player")


func start_chasing_player(player: CharacterBody3D) -> void:
	"""On Floor 5: Jump scare instead of chase"""
	print("Killer: PLAYER SPOTTED! JUMP SCARE!")
	
	# Trigger the jump scare overlay
	var jump_scare = get_tree().get_first_node_in_group("jump_scare")
	if jump_scare and jump_scare.has_method("trigger"):
		jump_scare.trigger()
	else:
		push_error("Killer: No JumpScare node found in scene!")


func lose_player() -> void:
	"""Player escaped, return to patrol"""
	print("Killer: Lost player, returning to idle")
	target_player = null
	current_state = State.PATROL if not patrol_points.is_empty() else State.IDLE


func _on_detection_body_entered(body: Node3D) -> void:
	"""Something entered detection sphere"""
	if body.is_in_group("player") and current_state != State.CHASE:
		print("Killer: Player entered detection range")
		if has_line_of_sight_to_player(body):  # ✅ Pass the player body
			start_chasing_player(body)
		else:
			print("Killer: Player in range but no line of sight")


func _on_detection_body_exited(body: Node3D) -> void:
	"""Something left detection sphere"""
	if body == target_player:
		print("Killer: Player left detection range")
		lose_player()


# Helper function to add patrol points from editor
func add_patrol_point(point: Vector3) -> void:
	patrol_points.append(point)
	if current_state == State.IDLE and not patrol_points.is_empty():
		current_state = State.PATROL
		nav_agent.target_position = patrol_points[0]
