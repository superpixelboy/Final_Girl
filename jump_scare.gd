extends CanvasLayer
class_name JumpScare

## Full-screen jump scare overlay
## Plays animated frames with sound, then game over

@export var frame_textures: Array[Texture2D] = []  # Drag your 3 PNG files here
@export var shake_sound: AudioStream  # JumpScareSound.mp3
@export var splatter_sound: AudioStream  # Blood splatter sound effect
@export var shake_duration: float = 1.5  # How long the shaking lasts
@export var still_duration: float = 0.5  # Pause before blood
@export var blood_duration: float = 1.0  # How long to show blood

@onready var black_bg: ColorRect = $BlackBackground
@onready var scare_image: TextureRect = $ScareImage
@onready var shake_player: AudioStreamPlayer = $ShakePlayer
@onready var splatter_player: AudioStreamPlayer = $SplatterPlayer

var is_playing: bool = false

func _ready() -> void:
	# Start hidden
	hide()

func trigger() -> void:
	"""Play the jump scare sequence"""
	if is_playing:
		return
	
	is_playing = true
	show()
	
	# Lock player controls
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
	
	# Play the sequence
	await play_shake_phase()
	await play_still_phase()
	await play_blood_phase()
	
	# Game over
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()

func play_shake_phase() -> void:
	"""Violently shake the clean smiley face"""
	if frame_textures.is_empty():
		push_error("JumpScare: No frame textures assigned!")
		return
	
	# Use ONLY frame 1 (clean smiley) during shake
	scare_image.texture = frame_textures[0]
	
	# Play shake sound
	if shake_sound:
		shake_player.stream = shake_sound
		shake_player.play()
	
	# Shake animation - move the image violently
	var elapsed: float = 0.0
	var frame_time: float = 0.05  # Update every 50ms for violent effect
	
	while elapsed < shake_duration:
		# Random offset for shake
		scare_image.position = Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)
		
		await get_tree().create_timer(frame_time).timeout
		elapsed += frame_time

func play_still_phase() -> void:
	"""Stop shaking, brief pause"""
	# Reset position
	scare_image.position = Vector2.ZERO
	
	# Still showing clean smiley (frame 1)
	await get_tree().create_timer(still_duration).timeout

func play_blood_phase() -> void:
	"""Show blood splatter frames 2 and 3"""
	if frame_textures.size() < 2:
		return
	
	# PLAY SPLATTER SOUND
	if splatter_sound:
		splatter_player.stream = splatter_sound
		splatter_player.play()
	
	# Show frame 2 briefly
	if frame_textures.size() >= 2:
		scare_image.texture = frame_textures[1]
		await get_tree().create_timer(blood_duration * 0.3).timeout  # 30% of blood time
	
	# Show frame 3 (full blood)
	if frame_textures.size() >= 3:
		scare_image.texture = frame_textures[2]
		await get_tree().create_timer(blood_duration * 0.7).timeout  # 70% of blood time
