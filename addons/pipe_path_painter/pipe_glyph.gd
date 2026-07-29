@tool
extends Control

## Draws a connection mask as a little pipe diagram: a hub with a stub toward
## every connected side. Used next to each slot in the config dialog so a name
## like "Tee North" can never be misread.

var mask := 0:
	set(value):
		mask = value
		queue_redraw()

var line_color := Color(0.55, 0.85, 1.0):
	set(value):
		line_color = value
		queue_redraw()


func _init(initial_mask: int = 0, side: float = 24.0) -> void:
	mask = initial_mask
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var reach := minf(size.x, size.y) * 0.5
	var thickness := maxf(2.0, reach * 0.28)

	draw_arc(center, reach * 0.9, 0, TAU, 24, Color(line_color, 0.15), 1.0)
	for direction in PipeTileLayout.mask_directions(mask):
		draw_line(center, center + Vector2(direction) * reach, line_color, thickness)
	draw_circle(center, thickness * 0.6, line_color)
