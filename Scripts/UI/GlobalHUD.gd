extends CanvasLayer

var heart_full_color := Color(1, 0.1, 0.1)
var heart_empty_color := Color(0.3, 0.3, 0.3)
var heart_size := Vector2(32, 32)

var heart_container : HBoxContainer
var heart_texture : Texture2D

func _ready() -> void:
	heart_texture = load("res://Sprites/heart.png")
	heart_container = HBoxContainer.new()
	heart_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	heart_container.position = Vector2(20, 20)
	add_child(heart_container)
	call_deferred("build_hearts")

func build_hearts() -> void:
	var max_health = PlayerManager.player.baseHealth
	for i in max_health:
		var heart := TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = heart_size
		heart.size = heart_size
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_SCALE
		heart.size = Vector2(32, 32)
		heart_container.add_child(heart)
	update_hearts()

func update_hearts() -> void:
	var current = PlayerManager.player._currentHealth
	for i in heart_container.get_child_count():
		var heart := heart_container.get_child(i) as TextureRect
		heart.modulate = heart_full_color if i < current else heart_empty_color
