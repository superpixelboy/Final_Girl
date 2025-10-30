extends CanvasLayer

## Simple interaction prompt UI
## Shows "Press E to Hide" etc.

@onready var prompt_label: Label = $PromptPanel/Label

func _ready() -> void:
	hide_prompt()

func show_prompt(text: String) -> void:
	prompt_label.text = text
	$PromptPanel.visible = true

func hide_prompt() -> void:
	$PromptPanel.visible = false
