extends Node3D

@export var examination_camera: Camera3D
@export var item_holder: Node3D
@export var examination_light: Light3D
@export var rotation_speed: float = 0.3
@export var pickup_sound: AudioStream  # NEW: Drag Item Pickup.mp3 here in inspector

var is_examining: bool = false
var current_item: Node3D = null
var current_item_name: String = ""
var current_item_description: String = ""
var player = null
var player_camera = null
var examination_ui: Control = null
var audio_player: AudioStreamPlayer  # NEW

func _ready():
	visible = false
	if examination_camera:
		examination_camera.current = false
	
	# NEW: Setup audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "PickupAudio"
	audio_player.bus = "Master"
	add_child(audio_player)
	
	call_deferred("setup_examination_ui")


func setup_examination_ui():
	examination_ui = Control.new()
	examination_ui.name = "ExaminationUI"
	examination_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	examination_ui.add_child(bg)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.position.y = 50
	name_label.add_theme_font_size_override("font_size", 32)
	examination_ui.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	desc_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	desc_label.position.y = -100
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	examination_ui.add_child(desc_label)
	
	var controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.text = "Drag mouse to rotate | E or ESC to take"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	controls_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls_label.position.y = -50
	controls_label.add_theme_font_size_override("font_size", 16)
	examination_ui.add_child(controls_label)
	
	add_child(examination_ui)
	examination_ui.visible = false

func start_examination(
	item_mesh: Node3D, 
	item_name: String, 
	description: String = "",
	position_offset: Vector3 = Vector3.ZERO,
	rotation_euler: Vector3 = Vector3.ZERO,
	scale_multiplier: float = 1.0
):
	print("\n=== EXAMINATION DEBUG ===")
	print("Item name: ", item_name)
	print("Item mesh node: ", item_mesh)
	print("Item mesh type: ", item_mesh.get_class())
	
	# NEW: Play pickup sound
	if pickup_sound and audio_player:
		audio_player.stream = pickup_sound
		audio_player.play()
		print("Playing pickup sound!")
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: No player!")
		return
	
	current_item = item_mesh
	current_item_name = item_name
	current_item_description = description if description != "" else "A useful item."
	
	player.lock_movement()
	player_camera = get_viewport().get_camera_3d()
	
	# Add item and reset transform
	if item_holder:
		print("Adding item to holder...")
		item_holder.add_child(current_item)
		
		# COMPLETELY reset transform
		current_item.transform = Transform3D.IDENTITY
		current_item.position = position_offset
		current_item.rotation_degrees = rotation_euler
		current_item.scale = Vector3.ONE * scale_multiplier
		current_item.visible = true
		
		print("Item after setup:")
		print("  Local Position: ", current_item.position)
		print("  Global Position: ", current_item.global_position)
		print("  Rotation: ", current_item.rotation_degrees)
		print("  Scale: ", current_item.scale)
		print("  Visible: ", current_item.visible)
		
		# Force all children visible
		for child in current_item.get_children():
			print("  Child: ", child.name, " (", child.get_class(), ") Visible: ", child.visible)
			child.visible = true
	
	# Camera info
	if examination_camera:
		examination_camera.current = true
		print("\nCamera:")
		print("  Position: ", examination_camera.global_position)
		print("  Rotation: ", examination_camera.rotation_degrees)
		print("  Looking direction: ", -examination_camera.global_transform.basis.z)
	
	# Light info
	if examination_light:
		examination_light.visible = true
		print("\nLight:")
		print("  Position: ", examination_light.global_position)
		print("  Type: ", examination_light.get_class())
	
	# Update UI
	if examination_ui:
		var name_label = examination_ui.get_node("NameLabel")
		var desc_label = examination_ui.get_node("DescLabel")
		if name_label:
			name_label.text = current_item_name
		if desc_label:
			desc_label.text = current_item_description
		examination_ui.visible = true
	
	is_examining = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	print("=== EXAMINATION STARTED ===\n")

func _process(_delta):
	if not is_examining or not current_item:
		return
	
	# Controller thumbstick rotation - CONTINUOUS
	var stick_input = Input.get_vector("tank_rotate_left", "tank_rotate_right", "tank_forward", "tank_back")
	if stick_input.length() > 0.1:  # Deadzone
		current_item.rotate_y(-stick_input.x * rotation_speed * 0.05)
		current_item.rotate_x(stick_input.y * rotation_speed * 0.05)

func _input(event):
	if not is_examining:
		return
	
	# Mouse rotation - NO CLICK NEEDED
	if event is InputEventMouseMotion:
		if current_item:
			current_item.rotate_y(-event.relative.x * rotation_speed * 0.01)
			current_item.rotate_x(-event.relative.y * rotation_speed * 0.01)
	
	# Exit examination
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		confirm_pickup()

func confirm_pickup():
	print("ItemExamination: Taking ", current_item_name)
	
	if item_holder and current_item:
		item_holder.remove_child(current_item)
	
	if examination_ui:
		examination_ui.visible = false
	
	if examination_light:
		examination_light.visible = false
	
	visible = false
	is_examining = false
	
	if player_camera:
		player_camera.current = true
	
	if player and current_item:
		player.add_to_inventory(current_item_name, current_item)
	
	if player:
		player.unlock_movement()
	
	current_item = null
	current_item_name = ""
	current_item_description = ""
	# LEAVE CURSOR VISIBLE
