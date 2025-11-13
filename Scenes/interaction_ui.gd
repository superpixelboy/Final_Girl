extends CanvasLayer
## Simple interaction prompt UI
## Shows "Press E to Pick Up" etc.

@onready var prompt_label: Label = $PromptPanel/Label

func _ready() -> void:
	# Add to ui group so other scripts can find us
	add_to_group("ui")
	hide_prompt()
	print("UI: Interaction UI ready and added to 'ui' group")

func show_prompt(text: String) -> void:
	prompt_label.text = text
	$PromptPanel.visible = true
	print("UI: Showing prompt: ", text)

func hide_prompt() -> void:
	$PromptPanel.visible = false
	print("UI: Hiding prompt")
	
func update_inventory(item_names: Array, active_item_name: String) -> void:
	"""Display the player's inventory"""
	if not has_node("InventoryLabel"):
		return
	
	var label = $InventoryLabel
	
	if item_names.size() == 0:
		label.text = ""
		return
	
	var text = "INVENTORY:\n"
	for item in item_names:
		if item == active_item_name:
			text += "► " + item + "\n"  # Arrow shows active item
		else:
			text += "  " + item + "\n"
	
	text += "\n[Tab] to switch"
	label.text = text
