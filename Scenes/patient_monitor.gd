extends Area3D

@export var requires_item: String = "Power Cord"
@export var monitor_node: Node3D  # Drag the monitor FBX here
@export var blank_texture: Texture2D  # M_PatientMonitor.png
@export var clue_texture: Texture2D   # M_PatientMonitor2.png (with smiley)
@export var examine_camera: Camera3D  # Camera positioned to look at monitor

var player_nearby: bool = false
var is_plugged_in: bool = false
var is_examining: bool = false
var monitor_mesh: MeshInstance3D = null
var interaction_ui = null
var previous_camera: Camera3D = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 2
	collision_mask = 1
	
	if monitor_node:
		monitor_mesh = find_mesh_in_node(monitor_node)
		if monitor_mesh:
			print("Monitor: Found monitor mesh: ", monitor_mesh.name)
	
	if monitor_mesh and blank_texture:
		set_monitor_texture(blank_texture)
	
	call_deferred("find_ui")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]
		print("Monitor: Found UI via group")
		return
	
	var ui_paths = ["/root/Floor5/UI", "../UI", "../../UI"]
	for path in ui_paths:
		if has_node(path):
			interaction_ui = get_node(path)
			print("Monitor: Found UI via path: ", path)
			return

func find_mesh_in_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = find_mesh_in_node(child)
		if result:
			return result
	return null

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		if is_examining:
			exit_examination()
		elif player_nearby:
			interact_with_monitor()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if not is_examining:
			update_interaction_prompt(body)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		if not is_examining:
			hide_interaction_prompt()

func update_interaction_prompt(player):
	if not is_plugged_in:
		var has_cord = player.get_held_item_name() == requires_item
		if has_cord:
			show_interaction_prompt("Press E to plug in Power Cord")
		else:
			show_interaction_prompt("Press E to examine Monitor")
	else:
		# After plugged in, can still examine
		show_interaction_prompt("Press E to examine Monitor")

func interact_with_monitor():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if not is_plugged_in:
		if player.get_held_item_name() == requires_item:
			plug_in_monitor(player)
		else:
			enter_examination(player)
	else:
		# If plugged in, just examine
		enter_examination(player)

func plug_in_monitor(player):
	if player.has_method("unequip_item"):
		player.unequip_item()
	
	is_plugged_in = true
	print("Monitor plugged in! Screen turns on...")
	
	if monitor_mesh and clue_texture:
		set_monitor_texture(clue_texture)
	
	# Auto-examine after plugging in
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		enter_examination(player_node)

func enter_examination(player):
	if not examine_camera:
		print("Monitor: No examine camera set!")
		return
	
	is_examining = true
	previous_camera = get_viewport().get_camera_3d()
	examine_camera.current = true
	
	if player.has_method("lock_movement"):
		player.lock_movement()
	
	# Show message using the same prompt system
	if not is_plugged_in:
		show_interaction_prompt("Weird, it's not plugged in.\n\nPress E to stop examining")
	else:
		show_interaction_prompt("Error No. 3  :)\n\nPress E to stop examining")
	
	print("Monitor: Entering examination mode")

func exit_examination():
	if not is_examining:
		return
	
	is_examining = false
	
	if previous_camera:
		previous_camera.current = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unlock_movement"):
		player.unlock_movement()
	
	if player_nearby and player:
		update_interaction_prompt(player)
	else:
		hide_interaction_prompt()
	
	print("Monitor: Exiting examination mode")

func set_monitor_texture(texture: Texture2D):
	if not monitor_mesh:
		return
	
	var material = monitor_mesh.get_surface_override_material(0)
	
	if not material:
		if monitor_mesh.mesh:
			material = monitor_mesh.mesh.surface_get_material(0)
			if material:
				material = material.duplicate()
				monitor_mesh.set_surface_override_material(0, material)
	
	if not material:
		material = StandardMaterial3D.new()
		monitor_mesh.set_surface_override_material(0, material)
	
	if material is StandardMaterial3D:
		material.albedo_texture = texture

func show_interaction_prompt(text: String):
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(text)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
