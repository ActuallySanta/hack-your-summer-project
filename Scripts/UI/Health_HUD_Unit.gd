class_name HealthUnit extends Sprite2D

const PIXELS_WIDE_RAW := 12
const PIXELS_TALL_RAW := 10
const PIXELS_SPACE := 1
const PIXELS_WIDE_TOTAL := PIXELS_WIDE_RAW + PIXELS_SPACE
const PIXELS_TALL_TOTAL := PIXELS_TALL_RAW + PIXELS_SPACE

func is_active() -> bool:
	return frame != 0

func make_alive(alive: bool) -> void:
	frame = 1 if alive else 2
