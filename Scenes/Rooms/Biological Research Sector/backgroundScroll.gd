extends Sprite2D

@export var tiles_per_second := Vector2.ZERO

var region_position: Vector2 = region_rect.position

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	region_rect.position += 16 * tiles_per_second * delta
