extends CharacterBody3D
## ULTRA DEBUG VERSION - Makes crowbar IMPOSSIBLE to miss
## With giant size, bright debug cube, and tons of debug output

@export_group("Movement")
@export var walk_speed := 2.5
@export var run_speed := 4.5
@export var rotation_speed := 2.5
@export var acceleration := 8.0

@export_group("Animation")
@export var turn_animation_threshold := 0.3

@export_group("Setup")
@export var starting_camera: Camera3D

@export_group("Hiding")
@export var interaction_range := 1.5

@export_group("Item Holding - ULTRA DEBUG MODE")
@export var hand_position := Vector3(0.0, 2.0, 5.0)  ## WAY OUT FRONT, HEAD HEIGHT
@export var hand_item_scale := Vector3(5.0, 5.0, 5.0)  ## GIANT SIZE
#@export var show_debug_cube := true  ## Show bright cube at hand position

# Movement state
var is_running := false
var can_move := true

# Hiding state
enum State { NORMAL, HIDING }
var current_state: State = State.NORMAL
var current_hiding_spot: Area3D = null

# UI
var interaction_prompt_visible: bool = false
var interaction_prompt_text: String = ""
@onready var interaction_ui: CanvasLayer = null

# Item holding system
var held_item_name: String = ""
var held_item_node: Node3D = null
var right_hand: Node3D = null
var debug_cube: MeshInstance3D = null  # Visual indicator

# Components
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _skin: Node3D = $Armature/Skeleton3D
@onready var _armature: Node3D = $Armature


func _ready() -> void:
	print("\n========================================")
	print("PLAYER ULTRA DEBUG MODE ACTIVATED")
	print("========================================\n")
	
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
	
	# CREATE RIGHT HAND POSITION
	print("\n>>> CREATING RIGHT HAND POSITION <<<")
	right_hand = Node3D.new()
	right_hand.name = "RightHandPosition"
	add_child(right_hand)
	right_hand.position = hand_position
	
	print("✓ RightHandPosition created")
	print("  Local position: ", right_hand.position)
	print("  World position: ", right_hand.global_position)
	

	
	print("\n========================================\n")





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
	
	# Check for interaction input FIRST
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
	
	# Direct velocity
	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	
	# Update animations
	_update_animation(move_input, rotation_input)
	
	# Character model faces movement direction
	if move_input != 0:
		_skin.rotation.y = 0


func process_hiding_state(_delta: float) -> void:
	"""Player is hiding - limited controls"""
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
				print("Player: Successfully entered hiding spot")
				return


func enter_hiding_state(hiding_spot: Area3D) -> void:
	current_state = State.HIDING
	current_hiding_spot = hiding_spot
	
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
# ITEM HOLDING SYSTEM - ULTRA DEBUG VERSION
# ============================================================================

func equip_item(item_name_param: String, item_node: Node3D) -> void:
	print("\n========================================")
	print(">>> EQUIPPING ITEM <<<")
	print("========================================")
	print("Item name: ", item_name_param)
	print("Item node: ", item_node.name if item_node else "NULL")
	print("Item type: ", item_node.get_class() if item_node else "NULL")
	
	if not right_hand:
		print("❌ ERROR: No right_hand node!")
		return
	
	print("✓ Right hand exists")
	print("  Hand local pos: ", right_hand.position)
	print("  Hand world pos: ", right_hand.global_position)
	
	# Store references
	held_item_name = item_name_param
	held_item_node = item_node
	
	# Remove from world
	if item_node.get_parent():
		print("✓ Removing item from parent: ", item_node.get_parent().name)
		item_node.get_parent().remove_child(item_node)
	
	# Add to hand
	print("✓ Adding item to right hand...")
	right_hand.add_child(item_node)
	
	# Reset transform
	item_node.position = Vector3.ZERO
	item_node.rotation = Vector3.ZERO
	item_node.scale = hand_item_scale
	item_node.visible = true
	
	print("✓ Item equipped!")
	print("  Item local pos: ", item_node.position)
	print("  Item world pos: ", item_node.global_position)
	print("  Item scale: ", item_node.scale)
	print("  Item visible: ", item_node.visible)
	print("  Item parent: ", item_node.get_parent().name if item_node.get_parent() else "NULL")
	
	# List all meshes in the item
	print("\n  Item children:")
	for child in item_node.get_children():
		print("    - ", child.name, " (", child.get_class(), ") visible: ", child.visible)
	
	print("========================================\n")
	
	# Hide debug cube now that we have an item
	if debug_cube:
		debug_cube.visible = false


func unequip_item() -> void:
	if held_item_node:
		held_item_node.queue_free()
	
	held_item_name = ""
	held_item_node = null
	



func has_item() -> bool:
	return held_item_name != ""


func get_held_item_name() -> String:
	return held_item_name


func use_held_item() -> bool:
	if held_item_node and held_item_node.has_method("use_item"):
		var success = held_item_node.use_item()
		if success:
			unequip_item()
			return true
	return false


# ============================================================================
# MOVEMENT LOCK FUNCTIONS
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
	return current_state == State.HIDING


func get_hiding_spot() -> Area3D:
	return current_hiding_spot


func die() -> void:
	print("Player: DEATH!")
	can_move = false
	velocity = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
