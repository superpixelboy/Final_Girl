extends CharacterBody3D

@export_group("Movement")
@export var walk_speed := 2.5
@export var run_speed := 4.5
@export var rotation_speed := 2.5
@export var acceleration := 8.0


@export_group("Controls")
@export_enum("Tank", "Analog") var control_scheme := 0  # 0 = Tank, 1 = Analog

@export_group("Animation")
@export var turn_animation_threshold := 0.3

@export_group("Setup")
@export var starting_camera: Camera3D

@export_group("Hiding")
@export var interaction_range := 1.5

@export_group("Item Holding")
@export var hand_position := Vector3(0.4, 1.2, 0.6)
@export var hand_item_scale := Vector3(1.0, 1.0, 1.0)

# Movement state
var is_running := false
var can_move := true
var current_camera: Camera3D = null
var previous_camera: Camera3D = null

# Analog control direction locking (for smooth camera transitions)
var locked_move_direction: Vector3 = Vector3.ZERO
var locked_input_dir: Vector2 = Vector2.ZERO  # NEW: Track what input locked us
var is_direction_locked: bool = false

# Hiding state
enum State { NORMAL, HIDING }
var current_state: State = State.NORMAL
var current_hiding_spot: Area3D = null

# UI
var interaction_ui: CanvasLayer = null

# INVENTORY SYSTEM - Multiple items
var inventory: Dictionary = {}  # {"item_name": node_reference}
var active_item: String = ""  # Currently equipped item name
var right_hand: Node3D = null

# Components
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _skin: Node3D = $Armature/Skeleton3D
@onready var _armature: Node3D = $Armature

@export_group("Audio")
@export var footstep_walk_loop: AudioStream  # Slow version for walking
@export var footstep_run_loop: AudioStream   # Fast version for running

var footstep_player: AudioStreamPlayer = null 

func _ready() -> void:
	# Activate starting camera
	if starting_camera:
		starting_camera.current = true
		current_camera = starting_camera
		previous_camera = starting_camera
	
	# Start with idle animation
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")
	
	# Add to player group
	add_to_group("player")
	
	# Find UI layer
	call_deferred("find_ui")
	
	
	# Create right hand position for holding items
	right_hand = Node3D.new()
	right_hand.name = "RightHandPosition"
	add_child(right_hand)
	right_hand.position = hand_position
	
	# Setup footstep audio system
	setup_footstep_audio()
	
	
	
	print("Player: Inventory system ready")
	print("Control Scheme: ", "Tank" if control_scheme == 0 else "Analog")


func find_ui() -> void:
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		update_inventory_ui()
		return
	
	var ui_paths = ["../UI", "/root/Floor5/UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			update_inventory_ui()
			break

# ============================================================================
# FOOTSTEP AUDIO SYSTEM
# ============================================================================
func setup_footstep_audio() -> void:
	"""Initialize footstep audio system"""
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "FootstepPlayer"
	footstep_player.volume_db = -5.0
	add_child(footstep_player)
	
	# Start with walking loop
	if footstep_walk_loop:
		footstep_player.stream = footstep_walk_loop
		
		if footstep_walk_loop is AudioStreamWAV:
			footstep_walk_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif footstep_walk_loop is AudioStreamOggVorbis:
			footstep_walk_loop.loop = true
		
		# Also set loop on run audio if it exists
		if footstep_run_loop:
			if footstep_run_loop is AudioStreamWAV:
				footstep_run_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			elif footstep_run_loop is AudioStreamOggVorbis:
				footstep_run_loop.loop = true
		
		footstep_player.play()
		footstep_player.volume_db = -80.0
		print("Player: Footstep audio system ready")

func update_footstep_audio() -> void:
	"""Control footstep volume and swap audio based on running"""
	var has_input = false
	
	if control_scheme == 0:
		var move_input = Input.get_axis("tank_forward", "tank_back")
		has_input = abs(move_input) > 0.1
	else:
		var input_dir = Vector2(
			Input.get_action_strength("tank_rotate_right") - Input.get_action_strength("tank_rotate_left"),
			Input.get_action_strength("tank_back") - Input.get_action_strength("tank_forward")
		)
		has_input = input_dir.length() > 0.1
	
	var should_play_footsteps = can_move and has_input and current_state == State.NORMAL
	
	if should_play_footsteps:
		# Switch audio stream based on running
		var target_stream = footstep_run_loop if is_running else footstep_walk_loop
		if footstep_player.stream != target_stream and target_stream != null:
			footstep_player.stream = target_stream
			footstep_player.play()
		
		footstep_player.volume_db = -5.0
	else:
		footstep_player.volume_db = -80.0
		
func _input(event: InputEvent) -> void:
	# Toggle control scheme with F1
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		control_scheme = 1 - control_scheme  # Toggle between 0 and 1
		print("Control Scheme switched to: ", "Tank" if control_scheme == 0 else "Analog")
		
		# Reset direction lock when switching schemes
		is_direction_locked = false
		locked_move_direction = Vector3.ZERO
		locked_input_dir = Vector2.ZERO
		
		# Show notification to player
		if interaction_ui and interaction_ui.has_method("show_notification"):
			var scheme_name = "Tank Controls" if control_scheme == 0 else "Analog Controls"
			interaction_ui.show_notification(scheme_name)


func _physics_process(delta: float) -> void:
	# Update current camera reference
	update_current_camera()
	
	# Handle inventory switching
	if current_state == State.NORMAL and can_move:
		if Input.is_action_just_pressed("next_item"):
			cycle_inventory(1)
		elif Input.is_action_just_pressed("last_item"):
			cycle_inventory(-1)
	
	# Different behavior based on state
	match current_state:
		State.NORMAL:
			if control_scheme == 0:
				process_tank_movement(delta)
			else:
				process_analog_movement(delta)
		State.HIDING:
			process_hiding_state(delta)


func update_current_camera() -> void:
	"""Track the currently active camera for analog controls"""
	var viewport = get_viewport()
	if viewport and viewport.get_camera_3d():
		var new_camera = viewport.get_camera_3d()
		
		# Detect camera change
		if new_camera != current_camera and control_scheme == 1:
			previous_camera = current_camera
			current_camera = new_camera
			
			# If we're moving when camera changes, lock the direction
			if locked_move_direction.length() > 0.1:
				is_direction_locked = true
				print("Camera changed - direction locked to world space")
		else:
			current_camera = new_camera


func process_tank_movement(delta: float) -> void:
	"""Original tank control movement"""
	if not can_move:
		return
	
	# Check for interaction
	if Input.is_action_just_pressed("interact"):
		try_interact()
	
	# Get input
	var rotation_input := Input.get_axis("tank_rotate_left", "tank_rotate_right")
	var move_input := Input.get_axis("tank_forward", "tank_back")
	
	# Hold to run
	is_running = Input.is_action_pressed("run_toggle")
	
	# Tank control rotation
	if rotation_input != 0:
		rotate_y(-rotation_input * rotation_speed * delta)
	
	# Tank control movement
	var current_speed := run_speed if is_running else walk_speed
	var move_direction := -global_transform.basis.z * move_input
	move_direction.y = 0.0
	
	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	_update_animation(move_input, rotation_input)
	
	if move_input != 0:
		_skin.rotation.y = 0
		
	update_footstep_audio()  


func process_analog_movement(delta: float) -> void:
	"""Modern analog control movement (camera-relative) with direction locking"""
	if not can_move:
		return
	
	# Check for interaction
	if Input.is_action_just_pressed("interact"):
		try_interact()
	
	# Get input (reuse tank controls for now)
	var input_dir = Vector2(
		Input.get_action_strength("tank_rotate_right") - Input.get_action_strength("tank_rotate_left"),
		Input.get_action_strength("tank_back") - Input.get_action_strength("tank_forward")
	)
	
	# NORMALIZE INPUT - prevent diagonal movement from being faster
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	
	# Hold to run
	is_running = Input.is_action_pressed("run_toggle")
	
	# ANALOG MODE: Reduce speed by half for better control
	var current_speed := (run_speed if is_running else walk_speed) * 0.5
	
	# Check if input was released - unlock direction
	if input_dir.length() < 0.1:
		if is_direction_locked:
			print("Input released - direction unlocked")
		is_direction_locked = false
		locked_move_direction = Vector3.ZERO
		locked_input_dir = Vector2.ZERO
		velocity.x = 0
		velocity.z = 0
		_update_animation(0, 0)
	else:
		# NEW: Check if input direction changed while locked (player pressed new button)
		if is_direction_locked:
			var input_change = (input_dir - locked_input_dir).length()
			if input_change > 0.3:  # Threshold for detecting new input
				print("Input changed while locked - unlocking to use new direction")
				is_direction_locked = false
		
		# Player is giving input
		var move_dir: Vector3
		
		if is_direction_locked:
			# Use the locked world-space direction
			move_dir = locked_move_direction.normalized()
		else:
			# Calculate new direction from camera
			var cam_forward: Vector3
			var cam_right: Vector3
			
			if current_camera:
				cam_forward = -current_camera.global_transform.basis.z
				cam_right = current_camera.global_transform.basis.x
			else:
				# Fallback to world space
				cam_forward = Vector3.FORWARD
				cam_right = Vector3.RIGHT
			
			# Project to XZ plane (ignore Y)
			cam_forward.y = 0
			cam_right.y = 0
			cam_forward = cam_forward.normalized()
			cam_right = cam_right.normalized()
			
			# Calculate movement direction relative to camera
			move_dir = (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()
			
			# Store this as our locked direction (in case camera changes)
			locked_move_direction = move_dir
			locked_input_dir = input_dir  # Store the input that created this direction
		
		# Smoothly rotate character to face movement direction
		if move_dir.length() > 0:
			var target_rotation = atan2(move_dir.x, move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, 10.0 * delta)
		
		# Move in the direction
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		
		# Animation - use total input magnitude so ANY direction triggers walk
		_update_animation(input_dir.length(), 0)
		_skin.rotation.y = 0
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	
	update_footstep_audio()  # Add this line


func process_hiding_state(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if current_hiding_spot and current_hiding_spot.has_method("exit_hiding"):
			current_hiding_spot.exit_hiding()
	
	velocity = Vector3.ZERO
	
	if _animation_player.has_animation("idle"):
		if _animation_player.current_animation != "idle":
			_animation_player.play("idle")


func _update_animation(move_input: float, rotation_input: float) -> void:
	if abs(move_input) > 0.1:
		if is_running:
			if _animation_player.has_animation("Animations/walk"):
				if _animation_player.current_animation != "Animations/walk":
					_animation_player.play("Animations/walk")
					_animation_player.speed_scale = 1.5
		else:
			if _animation_player.has_animation("Animations/walk"):
				if _animation_player.current_animation != "Animations/walk":
					_animation_player.play("Animations/walk")
					_animation_player.speed_scale = 1.0
	elif abs(rotation_input) > turn_animation_threshold:
		if rotation_input < 0:
			if _animation_player.has_animation("Animations/turn_left"):
				if _animation_player.current_animation != "Animations/turn_left":
					_animation_player.play("Animations/turn_left")
		else:
			if _animation_player.has_animation("Animations/turn_right"):
				if _animation_player.current_animation != "Animations/turn_right":
					_animation_player.play("Animations/turn_right")
	else:
		if _animation_player.has_animation("idle"):
			if _animation_player.current_animation != "idle":
				_animation_player.play("idle")


# ============================================================================
# HIDING SYSTEM
# ============================================================================

func try_interact() -> void:
	if current_state != State.NORMAL:
		return
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var shape = SphereShape3D.new()
	shape.radius = interaction_range
	query.shape = shape
	query.transform = global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 16
	
	var results = space_state.intersect_shape(query, 10)
	
	for result in results:
		var area = result["collider"]
		if area is Area3D and area.has_method("try_hide_player"):
			if area.try_hide_player():
				return


func enter_hiding_state(hiding_spot: Area3D) -> void:
	current_state = State.HIDING
	current_hiding_spot = hiding_spot
	
	# Reset direction lock when hiding
	is_direction_locked = false
	locked_move_direction = Vector3.ZERO
	locked_input_dir = Vector2.ZERO
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	set_interaction_prompt(false, "")
	
	can_move = false
	velocity = Vector3.ZERO
	
	if _armature:
		_armature.visible = false
	
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")


func exit_hiding_state() -> void:
	current_state = State.NORMAL
	current_hiding_spot = null
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	if _armature:
		_armature.visible = true
	
	can_move = true


func set_interaction_prompt(show: bool, text: String = "") -> void:
	if not interaction_ui:
		return
	
	if show and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)
	elif interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()


# ============================================================================
# INVENTORY SYSTEM
# ============================================================================

func add_to_inventory(item_name_param: String, item_node: Node3D) -> void:
	"""Add an item to inventory without replacing existing items"""
	print("\n=== ADDING TO INVENTORY ===")
	print("Item: ", item_name_param)
	
	# Store in inventory dictionary
	inventory[item_name_param] = item_node
	
	# Remove from world
	if item_node.get_parent():
		item_node.get_parent().remove_child(item_node)
	
	# Add to hand (invisible for now)
	right_hand.add_child(item_node)
	item_node.position = Vector3.ZERO
	item_node.rotation = Vector3.ZERO
	item_node.scale = hand_item_scale
	item_node.visible = false
	
	# If this is our first item OR we don't have an active item, equip it
	if inventory.size() == 1 or active_item == "":
		switch_to_item(item_name_param)
	
	update_inventory_ui()
	print("Inventory now contains: ", inventory.keys())


func switch_to_item(item_name_param: String) -> void:
	"""Switch the actively displayed item"""
	if not inventory.has(item_name_param):
		return
	
	# Hide current active item
	if active_item != "" and inventory.has(active_item):
		inventory[active_item].visible = false
	
	# Set new active item (but keep it invisible for now)
	active_item = item_name_param
	# inventory[active_item].visible = true  # DISABLED - don't show items yet
	
	print("Active item: ", active_item)
	update_inventory_ui()


func cycle_inventory(direction: int) -> void:
	"""Cycle through inventory items (1 = next, -1 = previous)"""
	if inventory.size() <= 1:
		return
	
	var item_names = inventory.keys()
	var current_index = item_names.find(active_item)
	
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + direction) % item_names.size()
	
	switch_to_item(item_names[current_index])


func remove_from_inventory(item_name_param: String) -> void:
	"""Remove an item from inventory (e.g., after using it)"""
	if not inventory.has(item_name_param):
		return
	
	print("Removing from inventory: ", item_name_param)
	
	# Free the node
	if inventory[item_name_param]:
		inventory[item_name_param].queue_free()
	
	# Remove from dictionary
	inventory.erase(item_name_param)
	
	# If we just removed the active item, switch to another
	if active_item == item_name_param:
		if inventory.size() > 0:
			switch_to_item(inventory.keys()[0])
		else:
			active_item = ""
	
	update_inventory_ui()


func has_item(item_name_param: String) -> bool:
	"""Check if player has a specific item"""
	return inventory.has(item_name_param)


func get_active_item() -> String:
	"""Get the name of the currently equipped item"""
	return active_item


func update_inventory_ui() -> void:
	"""Update the UI to show current inventory"""
	if not interaction_ui or not interaction_ui.has_method("update_inventory"):
		return
	
	interaction_ui.update_inventory(inventory.keys(), active_item)


# Legacy compatibility - some scripts might still call this
func equip_item(item_name_param: String, item_node: Node3D) -> void:
	add_to_inventory(item_name_param, item_node)


func unequip_item() -> void:
	"""Legacy function - now removes active item"""
	if active_item != "":
		remove_from_inventory(active_item)


func get_held_item_name() -> String:
	"""Legacy function - returns active item"""
	return active_item


# ============================================================================
# MOVEMENT LOCK FUNCTIONS
# ============================================================================

func lock_movement() -> void:
	can_move = false
	velocity = Vector3.ZERO
	
	# Reset direction lock
	is_direction_locked = false
	locked_move_direction = Vector3.ZERO
	locked_input_dir = Vector2.ZERO
	
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")


func unlock_movement() -> void:
	can_move = true


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func is_hiding() -> bool:
	return current_state == State.HIDING


func get_hiding_spot() -> Area3D:
	return current_hiding_spot


func die() -> void:
	print("Player: DEATH!")
	can_move = false
	velocity = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
