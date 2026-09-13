extends TileMapLayer

@export var tile_map_index : Vector2i
@export var init_pos : Vector2i
@export var offset : Vector2i = Vector2i(0, 1)

var _cursor_pos : Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_cursor_pos = init_pos
	increment()

func increment_for(length: int) -> void:
	for i in length:
		increment()

func increment() -> void:
	set_cell(_cursor_pos, 0, tile_map_index)
	_cursor_pos += offset

func decrement() -> void:
	set_cell(_cursor_pos)
	# Protect against "Negative" extensions
	if _cursor_pos != init_pos:
		_cursor_pos -= offset

func reset() -> void:
	while _cursor_pos != init_pos:
		decrement()
