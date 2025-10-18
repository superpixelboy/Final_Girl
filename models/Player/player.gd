extends CharacterBody3D

## TANK CONTROLS + FIXED CAMERA SYSTEM
## Classic survival horror movement

@export_group("Movement")
@export var walk_speed := 1.5  # Was 2.5, now slower
@export var run_speed := 3.5   # Was 5.0, now slower
@export var rotation_speed := 2.5  # Was 3.0, slightly slower turning
@export var acceleration := 8.0

@export_group("Setup")
@export var starting_camera: Camera3D  ## Assign your first fixed camera here

var is_running := false
var can_move := true  ## For cutscenes/interactions later

@onready var _skin: Node3D = %"FemaleLowpolyMesh"

func _ready() -> void:
	# Activate starting camera if assigned
	if starting_camera:
		starting_camera.current = true

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	
	# TANK CONTROL ROTATION (left/right rotates character)
	var rotation_input := Input.get_axis("tank_rotate_left", "tank_rotate_right")
	if rotation_input != 0:
		rotate_y(-rotation_input * rotation_speed * delta)
	
	# TANK CONTROL MOVEMENT (forward/back in facing direction)
	var move_input := Input.get_axis( "tank_forward","tank_back")
	
	# HOLD TO RUN (not toggle)
	is_running = Input.is_action_pressed("run_toggle")
	
	# Calculate velocity based on character's facing direction
	var current_speed := run_speed if is_running else walk_speed
	var move_direction := -global_transform.basis.z * move_input
	move_direction.y = 0.0
	
	# Smooth acceleration
	var target_velocity := move_direction * current_speed
	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	
	# Character model always faces movement direction
	if move_input != 0:
		_skin.rotation.y = 0  # Face forward relative to CharacterBody3D

func lock_movement() -> void:
	can_move = false
	velocity = Vector3.ZERO

func unlock_movement() -> void:
	can_move = true
