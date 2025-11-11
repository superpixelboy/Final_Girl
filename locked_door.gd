extends Area3D

## Locked Door - Requires crowbar to open

@export var door_name: String = "Patient Room Door"
@export var locked_prompt: String = "Press E to open door"
@export var fade_duration: float = 1.0

## Drag your door visual here:
@export var door_mesh: Node3D

var player_nearby: bool = false
var is_open: bool = false
var is_interacting: bool = false

var interaction_ui = null
var fade_overlay = null
var player_ref = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 2
	collision_mask = 1
	
	print("Door: ", door_name, " ready")
	
	call_deferred("find_ui")
	call_deferred("setup_fade_overlay")

func find_ui():
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		interaction_ui = ui_nodes[0]

func setup_fade_overlay():
	fade_overlay = get_tree().get_first_node_in_group("fade_overlay")
	
	if not fade_overlay:
		var canvas = CanvasLayer.new()
		canvas.name = "FadeOverlay"
		canvas.layer = 100
		canvas.add_to_group("fade_overlay")
		
		var color_rect = ColorRect.new()
		color_rect.name = "FadeRect"
		color_rect.color = Color.BLACK
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.modulate.a = 0.0
		
		canvas.add_child(color_rect)
		get_tree().root.add_child(canvas)
		fade_overlay = canvas

func _process(_delta):
	if player_nearby and not is_open and not is_interacting:
		if Input.is_action_just_pressed("interact"):
			try_open_door()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_open:
		player_nearby = true
		player_ref = body
		show_interaction_prompt()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		hide_interaction_prompt()

func try_open_door():
	if player_ref and player_ref.has_method("has_item"):
		if player_ref.has_item() and player_ref.get_held_item_name() == "Crowbar":
			open_door_with_crowbar()
		else:
			door_locked_response()
	else:
		door_locked_response()

func door_locked_response():
	hide_interaction_prompt()
	
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt("It's locked from the other side")
		await get_tree().create_timer(2.0).timeout
		interaction_ui.hide_prompt()
	
	if player_nearby:
		show_interaction_prompt()

func open_door_with_crowbar():
	is_interacting = true
	hide_interaction_prompt()
	
	# 1. Lock player
	if player_ref and player_ref.has_method("lock_movement"):
		player_ref.lock_movement()
	
	# 2. Fade to black
	await fade_to_black()
	
	# 3. HIDE door mesh while screen is black (don't delete yet!)
	if door_mesh:
		door_mesh.visible = false
		print("Door: Door hidden")
	
	# 4. Remove crowbar
	if player_ref and player_ref.has_method("unequip_item"):
		player_ref.unequip_item()
	
	# 5. Wait a moment
	await get_tree().create_timer(0.5).timeout
	
	# 6. Fade back in
	await fade_from_black()
	
	# 7. Unlock player - THEY CAN MOVE NOW
	if player_ref and player_ref.has_method("unlock_movement"):
		player_ref.unlock_movement()
	
	print("Door: Player has control back, now cleaning up...")
	
	# 8. NOW delete everything (player already has control)
	queue_free()

func fade_to_black() -> void:
	if not fade_overlay:
		return
	
	var fade_rect = fade_overlay.get_node_or_null("FadeRect")
	if not fade_rect:
		return
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished

func fade_from_black() -> void:
	if not fade_overlay:
		return
	
	var fade_rect = fade_overlay.get_node_or_null("FadeRect")
	if not fade_rect:
		return
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	await tween.finished

func show_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("show_prompt"):
		interaction_ui.show_prompt(locked_prompt)

func hide_interaction_prompt():
	if interaction_ui and interaction_ui.has_method("hide_prompt"):
		interaction_ui.hide_prompt()
