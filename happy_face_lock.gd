extends Node3D

@export var correct_sequence: Array[String] = ["up", "up_right", "right", "down_right", "down"]
@export var unlock_door_path: NodePath
@export var lock_camera_path: NodePath = "LockCamera"
@export var button_press_duration := 0.15
@export var opened_lock_scene: PackedScene

@onready var padlock = $PadLock
@onready var lock_hook = $LockHook  
@onready var happy_face = $HappyFaceLock
@onready var animation_player = $AnimationPlayer

var current_inputs: Array[String] = []
var current_rotation: int = 0  # 0-7 for 8 directions
var is_active: bool = false
var is_unlocked: bool = false
var is_pressing: bool = false
var input_cooldown: bool = false

var original_camera: Camera3D
var lock_camera: Camera3D
var player_ref: CharacterBody3D
var interaction_ui = null

func _ready():
	add_to_group("happy_lock")
	
	if lock_camera_path:
		lock_camera = get_node(lock_camera_path)
		if lock_camera:
			print("Found lock camera at: ", lock_camera.global_position)
	
	# Find UI
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("HappyLock: Found UI")

func _process(_delta):
	if not is_active or is_unlocked or is_pressing or input_cooldown:
		return
	
	if Input.is_action_just_pressed("tank_rotate_left"):
		rotate_lock_left()
	elif Input.is_action_just_pressed("tank_rotate_right"):
		rotate_lock_right()
	
	if Input.is_action_just_pressed("interact"):
		submit_direction()
	
	if Input.is_action_just_pressed("ui_cancel"):
		deactivate_lock()

func activate_lock():
	if is_unlocked:
		return
	
	if is_active:
		print("Lock already active, ignoring re-activation")
		return
	
	is_active = true
	current_inputs.clear()
	current_rotation = 0
	is_pressing = false
	
	input_cooldown = true
	get_tree().create_timer(0.3).timeout.connect(func(): input_cooldown = false)
	
	player_ref = get_tree().get_first_node_in_group("player")
	
	original_camera = get_viewport().get_camera_3d()
	print("Stored original camera: ", original_camera.name if original_camera else "NONE")
	
	if lock_camera:
		lock_camera.make_current()
		print("Switched to lock camera")
	
	if player_ref:
		player_ref.lock_movement()
		
		var armature = player_ref.get_node_or_null("Armature")
		if armature:
			armature.visible = false
			print("Player model hidden")
	
	print("Lock activated. Use A/D to rotate, E to submit, ESC to exit")
	update_lock_visual()
	update_progress_ui()

func deactivate_lock():
	is_active = false
	
	print("Deactivating lock...")
	print("Original camera stored: ", original_camera.name if original_camera else "NONE")
	
	if original_camera and original_camera.name != "LockCamera":
		print("Restoring original camera: ", original_camera.name)
		original_camera.make_current()
	else:
		print("Fallback: Finding player's current camera zone...")
		if player_ref:
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsShapeQueryParameters3D.new()
			var shape = SphereShape3D.new()
			shape.radius = 0.5
			query.shape = shape
			query.transform = player_ref.global_transform
			query.collide_with_areas = true
			query.collide_with_bodies = false
			
			var results = space_state.intersect_shape(query, 10)
			for result in results:
				var area = result["collider"]
				if area.has_method("get") and area.get("associated_camera"):
					var cam = area.get("associated_camera")
					if cam:
						print("Found camera zone camera: ", cam.name)
						cam.make_current()
						break
	
	if player_ref:
		print("Unlocking player movement")
		player_ref.unlock_movement()
		
		var armature = player_ref.get_node_or_null("Armature")
		if armature:
			armature.visible = true
			print("Player model shown")
	
	# Hide UI
	hide_progress_ui()
	
	print("Lock deactivated")

func rotate_lock_left():
	current_rotation = (current_rotation - 1) % 8
	if current_rotation < 0:
		current_rotation = 7
	update_lock_visual()
	print("Rotated to: ", get_direction_name())

func rotate_lock_right():
	current_rotation = (current_rotation + 1) % 8
	update_lock_visual()
	print("Rotated to: ", get_direction_name())

func update_lock_visual():
	# 8 directions = 45-degree increments
	var target_rotation = current_rotation * 45
	happy_face.rotation_degrees.x = -target_rotation

func get_direction_name() -> String:
	match current_rotation:
		0: return "up"
		1: return "up_right"
		2: return "right"
		3: return "down_right"
		4: return "down"
		5: return "down_left"
		6: return "left"
		7: return "up_left"
	return "up"

func submit_direction():
	if is_pressing:
		return
	
	var direction = get_direction_name()
	current_inputs.append(direction)
	
	print("Submitted: ", direction, " (", current_inputs.size(), "/", correct_sequence.size(), ")")
	
	update_progress_ui()
	
	await button_press_effect()
	
	if current_inputs.size() >= correct_sequence.size():
		check_solution()

func button_press_effect():
	is_pressing = true
	
	var original_scale = happy_face.scale
	var original_pos = happy_face.position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(happy_face, "scale", original_scale * 0.9, button_press_duration * 0.5)
	tween.tween_property(happy_face, "position", original_pos + Vector3(0, 0, -0.05), button_press_duration * 0.5)
	
	await tween.finished
	
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(happy_face, "scale", original_scale, button_press_duration * 0.5)
	tween2.tween_property(happy_face, "position", original_pos, button_press_duration * 0.5)
	
	await tween2.finished
	
	# TODO: Play click sound here
	
	is_pressing = false

func check_solution():
	var correct = true
	
	for i in range(correct_sequence.size()):
		if i >= current_inputs.size() or current_inputs[i] != correct_sequence[i]:
			correct = false
			break
	
	if correct:
		unlock_lock()
	else:
		fail_attempt()

func unlock_lock():
	print("✓ CORRECT! UNLOCKED!")
	is_unlocked = true
	
	if animation_player.has_animation("Unlock"):
		animation_player.play("Unlock")
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	
	# TODO: Play unlock sound here
	
	if unlock_door_path:
		var door = get_node(unlock_door_path)
		if door and door.has_method("unlock"):
			door.unlock()
	
	deactivate_lock()
	
	if opened_lock_scene:
		var opened_lock = opened_lock_scene.instantiate()
		get_parent().add_child(opened_lock)
		opened_lock.global_position = global_position
		opened_lock.global_position.y -= 0.5
		print("Spawned opened lock at: ", opened_lock.global_position)
	
	var trigger = get_parent().get_node_or_null("HappyFaceLockZone")
	if trigger:
		trigger.queue_free()
		print("Deleted lock trigger zone")
	
	queue_free()
	print("Deleted lock puzzle")

func fail_attempt():
	print("✗ WRONG SEQUENCE!")
	
	# TODO: Play error sound here
	
	await get_tree().create_timer(0.5).timeout
	
	print("Exiting lock...")
	deactivate_lock()

func update_progress_ui():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		var progress_text = "Input: %d/%d\n\nA/D to rotate | E to submit | ESC to exit" % [current_inputs.size(), correct_sequence.size()]
		interaction_ui.show_prompt(progress_text)

func hide_progress_ui():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
