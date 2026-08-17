@tool
extends Control

## The little (i) that sits next to the region coords. Hovering it pops the
## read-only preview of everything the painter is about to scan.

const RectRegionPreview := preload("res://addons/rect_tile_painter/rect_region_preview.gd")

## Set by the toolbar whenever the tileset, source or mode changes.
var source: TileSetAtlasSource = null
var source_id := 0
var region_origin := Vector2i.ZERO
var terrain := false

var _hovered := false


func _init() -> void:
	custom_minimum_size = Vector2(18, 18)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Godot only asks for a custom tooltip when there is a tooltip to show, so
	# this string has to be non-empty even though it is never displayed.
	tooltip_text = " "


func describe(
	new_source: TileSetAtlasSource,
	new_source_id: int,
	new_origin: Vector2i,
	new_terrain: bool
) -> void:
	source = new_source
	source_id = new_source_id
	region_origin = new_origin
	terrain = new_terrain


func _make_custom_tooltip(_for_text: String) -> Object:
	var preview := RectRegionPreview.new()
	preview.configure(source, source_id, region_origin, terrain)
	return preview


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 1.0
	var tint := Color(1, 1, 1, 0.95) if _hovered else Color(1, 1, 1, 0.55)

	draw_circle(center, radius, tint, false, 1.0)
	# Dot and stem of the "i", drawn rather than typeset so it stays crisp at
	# whatever editor scale the user is on.
	draw_rect(Rect2(center + Vector2(-0.5, -radius * 0.55), Vector2(1.5, 1.5)), tint, true)
	draw_rect(Rect2(center + Vector2(-0.5, -radius * 0.15), Vector2(1.5, radius * 0.75)), tint, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		queue_redraw()
