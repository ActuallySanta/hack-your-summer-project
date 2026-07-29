@tool
extends Control

## The tileset's atlas texture, drawn at a zoom with a clickable tile grid.
##
## Godot's own tile palette doesn't publish a drag payload a plugin can accept,
## so rather than drag out of it we draw the same atlas here, right beside the
## slot list. Click a tile to assign it to the selected slot.

signal tile_hovered(coords: Vector2i)
signal tile_picked(coords: Vector2i)

const NONE := Vector2i(-1, -1)

var source: TileSetAtlasSource = null:
	set(value):
		source = value
		_refresh_size()

var zoom := 4.0:
	set(value):
		zoom = maxf(1.0, value)
		_refresh_size()

## Coord of the slot currently being edited -- drawn with a strong ring.
var highlight := NONE:
	set(value):
		highlight = value
		queue_redraw()

## coord -> slot name, for shading tiles that are already spoken for.
var assigned: Dictionary[Vector2i, String] = {}:
	set(value):
		assigned = value
		queue_redraw()

var _hovered := NONE


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click a tile to assign it to the selected slot."


func _refresh_size() -> void:
	if source == null or source.texture == null:
		custom_minimum_size = Vector2.ZERO
	else:
		custom_minimum_size = Vector2(source.texture.get_size()) * zoom
	queue_redraw()


func _draw() -> void:
	if source == null or source.texture == null:
		return

	draw_texture_rect(source.texture, Rect2(Vector2.ZERO, custom_minimum_size), false)

	for index in source.get_tiles_count():
		var coords := source.get_tile_id(index)
		var rect := _rect_for(coords)
		draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)

		if assigned.has(coords):
			draw_rect(rect, Color(0.35, 1.0, 0.55, 0.16), true)
			draw_rect(rect, Color(0.35, 1.0, 0.55, 0.75), false, 1.0)
			_draw_glyph(rect, PipeTileLayout.NAME_TO_MASK[assigned[coords]])

	if highlight != NONE and source.has_tile(highlight):
		draw_rect(_rect_for(highlight).grow(2.0), Color(1.0, 0.82, 0.25), false, 3.0)

	if _hovered != NONE and source.has_tile(_hovered):
		var rect := _rect_for(_hovered)
		draw_rect(rect, Color(1, 1, 1, 0.20), true)
		draw_rect(rect, Color(1, 1, 1, 0.95), false, 2.0)


## Miniature connection diagram in the corner of an assigned tile, so the
## atlas doubles as a map of what you've already set.
func _draw_glyph(rect: Rect2, mask: int) -> void:
	var reach := minf(rect.size.x, rect.size.y) * 0.22
	var center := rect.position + Vector2(rect.size.x - reach - 3.0, reach + 3.0)
	var color := Color(0.2, 1.0, 0.5)
	for direction in PipeTileLayout.mask_directions(mask):
		draw_line(center, center + Vector2(direction) * reach, color, maxf(1.0, reach * 0.35))


func _rect_for(coords: Vector2i) -> Rect2:
	var region := Rect2(source.get_tile_texture_region(coords))
	return Rect2(region.position * zoom, region.size * zoom)


## Exact hit test against real tile regions, so margins, separation and
## multi-cell tiles all behave.
func _coords_at(position: Vector2) -> Vector2i:
	if source == null:
		return NONE
	for index in source.get_tiles_count():
		var coords := source.get_tile_id(index)
		if _rect_for(coords).has_point(position):
			return coords
	return NONE


func _gui_input(event: InputEvent) -> void:
	if source == null:
		return

	if event is InputEventMouseMotion:
		var coords := _coords_at((event as InputEventMouseMotion).position)
		if coords != _hovered:
			_hovered = coords
			tile_hovered.emit(coords)
			queue_redraw()
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var coords := _coords_at(button.position)
			if coords != NONE:
				tile_picked.emit(coords)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hovered != NONE:
		_hovered = NONE
		tile_hovered.emit(NONE)
		queue_redraw()
