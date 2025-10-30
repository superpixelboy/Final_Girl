extends CharacterBody3D
## TANK CONTROLS + ANIMATION SYSTEM + HIDING MECHANIC (DEBUG VERSION)
## Classic survival horror movement with animations and hiding spots

@export_group("Movement")
@export var walk_speed := 2.5
@export var run_speed := 4.5
@export var rotation_speed := 2.5
@export var acceleration := 8.0

@export_group("Animation")
@export var turn_animation_threshold := 0.3  ## How much rotation before playing turn anims

@export_group("Setup")
@export var starting_camera: Camera3D  ## Assign your first fixed camera here

@export_group("Hiding")
@export var interaction_range := 1.5  ## How close to hiding spot to interact

# Movement state
var is_running := false
var can_move := true  ## For cutscenes/interactions later

# Hiding state
enum State { NORMAL, HIDING }
var current_state: State = State.NORMAL
var current_hiding_spot: Area3D = null

# UI
var interaction_prompt_visible: bool = false
var interaction_prompt_text: String = ""
@onready var interaction_ui: CanvasLayer = null  # Will be set in _ready

# Components
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _skin: Node3D = $Armature/Skeleton3D
@onready var _armature: Node3D = $Armature  ## Reference to hide/show model


func _ready() -> void:
	# Activate starting camera if assigned
	if starting_camera:
		starting_camera.current = true
	
	# Start with idle animation
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")
	
	# Add to player group for detection
	add_to_group("player")
	
	# DEBUG: Check armature reference
	if _armature:
		print("DEBUG Player: Armature found: ", _armature.name)
		print("DEBUG Player: Armature visible: ", _armature.visible)
	else:
		print("ERROR Player: Armature NOT found!")
	
	# Find UI layer for interaction prompts
	var ui_paths = ["../UI", "/root/Floor5/UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			break
	
	if not interaction_ui:
		push_warning("Player: No UI CanvasLayer found for interaction prompts")


func _physics_process(delta: float) -> void:
	# Different behavior based on state
	match current_state:
		State.NORMAL:
			process_normal_movement(delta)
		State.HIDING:
			process_hiding_state(delta)


func process_normal_movement(delta: float) -> void:
	"""Normal tank control movement"""
	if not can_move:
		return
	
	# Check for interaction input FIRST (before movement)
	if Input.is_action_just_pressed("interact"):
		try_interact()
	
	# Get input
	var rotation_input := Input.get_axis("tank_rotate_left", "tank_rotate_right")
	var move_input := Input.get_axis("tank_forward", "tank_back")
	
	# HOLD TO RUN (not toggle)
	is_running = Input.is_action_pressed("run_toggle")
	
	# TANK CONTROL ROTATION
	if rotation_input != 0:
		rotate_y(-rotation_input * rotation_speed * delta)
	
	# TANK CONTROL MOVEMENT
	var current_speed := run_speed if is_running else walk_speed
	var move_direction := -global_transform.basis.z * move_input
	move_direction.y = 0.0
	
	# Direct velocity (no lerp = instant stop)
	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	
	# Update animations based on input
	_update_animation(move_input, rotation_input)
	
	# Character model always faces movement direction
	if move_input != 0:
		_skin.rotation.y = 0  # Face forward relative to CharacterBody3D


func process_hiding_state(_delta: float) -> void:
	"""Player is hiding - limited controls"""
	# Can only exit hiding
	if Input.is_action_just_pressed("interact"):
		print("DEBUG Player: E pressed while hiding - attempting to exit")
		if current_hiding_spot and current_hiding_spot.has_method("exit_hiding"):
			current_hiding_spot.exit_hiding()
		else:
			print("ERROR Player: No hiding spot or no exit_hiding method!")
	
	# No movement while hiding
	velocity = Vector3.ZERO
	
	# Keep idle animation
	if _animation_player.has_animation("idle"):
		if _animation_player.current_animation != "idle":
			_animation_player.play("idle")


func _update_animation(move_input: float, rotation_input: float) -> void:
	# Priority: Movement animations override turning
	
	if abs(move_input) > 0.1:
		# Moving forward or backward
		if is_running:
			# You can add a run animation later
			if _animation_player.has_animation("Animations/walk"):
				if _animation_player.current_animation != "Animations/walk":
					_animation_player.play("Animations/walk")
					_animation_player.speed_scale = 1.5  # Speed up for running
		else:
			if _animation_player.has_animation("Animations/walk"):
				if _animation_player.current_animation != "Animations/walk":
					_animation_player.play("Animations/walk")
					_animation_player.speed_scale = 1.0  # Normal walk speed
	
	elif abs(rotation_input) > turn_animation_threshold:
		# Rotating in place (no forward/back movement)
		if rotation_input < 0:
			# Turning left
			if _animation_player.has_animation("Animations/turn_left"):
				if _animation_player.current_animation != "Animations/turn_left":
					_animation_player.play("Animations/turn_left")
		else:
			# Turning right
			if _animation_player.has_animation("Animations/turn_right"):
				if _animation_player.current_animation != "Animations/turn_right":
					_animation_player.play("Animations/turn_right")
	
	else:
		# Not moving or turning - idle
		if _animation_player.has_animation("idle"):
			if _animation_player.current_animation != "idle":
				_animation_player.play("idle")


# ============================================================================
# HIDING SYSTEM
# ============================================================================

func try_interact() -> void:
	"""Try to interact with nearby objects (like hiding spots)"""
	if current_state != State.NORMAL:
		return
	
	# Check for hiding spots in range using a sphere cast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create a small sphere around player to check for hiding spots
	var shape = SphereShape3D.new()
	shape.radius = interaction_range
	query.shape = shape
	query.transform = global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 16  # Layer 5 (hiding spots should be on this layer)
	
	var results = space_state.intersect_shape(query, 10)
	
	# Try to interact with closest hiding spot
	for result in results:
		var area = result["collider"]
		if area is Area3D and area.has_method("try_hide_player"):
			if area.try_hide_player():
				print("Player: Successfully entered hiding spot")
				return


func enter_hiding_state(hiding_spot: Area3D) -> void:
	"""Called by hiding spot when player enters"""
	print("DEBUG Player: enter_hiding_state() called")
	current_state = State.HIDING
	current_hiding_spot = hiding_spot
	
	# Disable collision so killer walks past
	set_collision_layer_value(1, false)  # Disable layer 1
	set_collision_mask_value(1, false)   # Disable mask 1
	
	# Hide interaction prompt
	set_interaction_prompt(false, "")
	
	# Lock movement
	can_move = false
	velocity = Vector3.ZERO
	
	# HIDE PLAYER MODEL
	print("DEBUG Player: Attempting to hide model...")
	print("DEBUG Player: _armature exists? ", _armature != null)
	if _armature:
		print("DEBUG Player: _armature.visible BEFORE: ", _armature.visible)
		_armature.visible = false
		print("DEBUG Player: _armature.visible AFTER: ", _armature.visible)
		print("Player: Model hidden ✓")
	else:
		print("ERROR Player: Cannot hide model - _armature is null!")
	
	# Play idle animation (even though not visible)
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")
	
	print("Player: Entered hiding state")


func exit_hiding_state() -> void:
	"""Called by hiding spot when player exits"""
	print("DEBUG Player: ========== exit_hiding_state() called ==========")
	print("DEBUG Player: Current state: ", State.keys()[current_state])
	
	current_state = State.NORMAL
	current_hiding_spot = null
	
	# Re-enable collision
	set_collision_layer_value(1, true)  # Enable layer 1
	set_collision_mask_value(1, true)   # Enable mask 1
	print("DEBUG Player: Collision re-enabled")
	
	# SHOW PLAYER MODEL
	print("DEBUG Player: Attempting to show model...")
	print("DEBUG Player: _armature exists? ", _armature != null)
	if _armature:
		print("DEBUG Player: _armature.visible BEFORE: ", _armature.visible)
		_armature.visible = true
		print("DEBUG Player: _armature.visible AFTER: ", _armature.visible)
		print("Player: Model visible ✓")
	else:
		print("ERROR Player: Cannot show model - _armature is null!")
	
	# Unlock movement
	can_move = true
	print("DEBUG Player: Movement unlocked")
	
	print("Player: Exited hiding state")
	print("DEBUG Player: ========== exit_hiding_state() complete ==========")


func set_interaction_prompt(visible: bool, text: String = "") -> void:
	"""Show/hide interaction prompt UI"""
	interaction_prompt_visible = visible
	interaction_prompt_text = text
	
	# Update UI if available
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		if visible:
			interaction_ui.show_prompt(text)
		else:
			interaction_ui.hide_prompt()
	elif visible:
		# Fallback: print to console if no UI
		print("Interaction: ", text)



# ============================================================================
# EXISTING MOVEMENT LOCK FUNCTIONS (preserved)
# ============================================================================

func lock_movement() -> void:
	can_move = false
	velocity = Vector3.ZERO
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")


func unlock_movement() -> void:
	can_move = true


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func is_hiding() -> bool:
	"""Check if player is currently hiding"""
	return current_state == State.HIDING


func get_hiding_spot() -> Area3D:
	"""Get current hiding spot (null if not hiding)"""
	return current_hiding_spot

func die() -> void:
	"""Player has been killed by the killer"""
	print("Player: DEATH!")
	
	# Disable all controls
	can_move = false
	velocity = Vector3.ZERO
	
	# Optional: Play death animation or sound here
	
	# Wait a moment, then reload
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
