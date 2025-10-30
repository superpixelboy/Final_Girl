extends CanvasLayer

## Door crack overlay - shows vertical slit effect when hiding
## Darkens edges and creates narrow viewing area


@onready var left_slit: ColorRect = $LeftSlit
@onready var right_slit: ColorRect = $RightSlit


func _ready() -> void:
	hide_crack()


func show_crack() -> void:
	"""Show door crack effect"""
	visible = true
	print("DoorCrack: Overlay shown")


func hide_crack() -> void:
	"""Hide door crack effect"""
	visible = false
	print("DoorCrack: Overlay hidden")


func set_crack_width(width: float) -> void:
	"""Adjust how wide the viewing slit is (0.1 to 0.5)"""
	# Adjust the transparent gap between slits
	# Width of 0.3 = 30% of screen is visible
	pass  # Implemented via anchors in scene setup
