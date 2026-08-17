@tool
extends Control

## The panel that pops up when you hover the (i) next to the region coords.
##
## It is a read-only window onto the name -> coordinate table: it draws the
## actual pixels the painter is about to read, laid out on the same grid, with
## the piece name and the absolute atlas coord on every cell. Nothing here
## edits anything -- if a piece is pointing at the wrong art you fix
## `rect_tile_layout.gd`, not the scene.

const TILE_PX := 40.0
const PAD := 8.0
const GUTTER_LEFT := 26.0
const GUTTER_TOP := 15.0
const HEADER := 17.0
const FOOTER := 15.0

## Longest prefix wins, so the "Small ..." entries must come before "Corner".
const ABBREVIATIONS: Dictionary[String, String] = {
	"Vertical Column": "Col",
	"Horizontal Bar": "Bar",
	"Double Inner Corner": "Dbl",
	"Inner Corner": "Inner",
	"Small Corner": "S-Cnr",
	"Small Tee": "S-Tee",
	"Small Cross": "S-X",
	"Big Tee": "B-Tee",
	"Step Corner": "StepC",
	"Step": "Step",
	"Corner": "Cnr",
	"Edge": "Edge",
}

var source: TileSetAtlasSource = null
var source_id := 0
var region_origin := Vector2i.ZERO
var terrain := false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called by the (i) control right before the tooltip is shown.
func configure(
	new_source: TileSetAtlasSource,
	new_source_id: int,
	new_origin: Vector2i,
	new_terrain: bool
) -> void:
	source = new_source
	source_id = new_source_id
	region_origin = new_origin
	terrain = new_terrain

	var region := RectTileLayout.region_size(terrain)
	custom_minimum_size = Vector2(
		PAD * 2.0 + GUTTER_LEFT + region.x * TILE_PX,
		PAD * 2.0 + HEADER + GUTTER_TOP + region.y * TILE_PX + FOOTER
	)
	queue_redraw()


func _draw() -> void:
	var region := RectTileLayout.region_size(terrain)
	var names := RectTileLayout.names_by_offset(terrain)
	var font := get_theme_default_font()

	var dim := Color(1, 1, 1, 0.45)
	var grid_line := Color(1, 1, 1, 0.14)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.13, 0.97), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12), false, 1.0)

	var mode_text := "Terrain 6x6" if terrain else "Basic 4x4"
	draw_string(
		font,
		Vector2(PAD, PAD + 11.0),
		"%s  ·  source %d  ·  %s to %s" % [
			mode_text, source_id, region_origin, region_origin + region - Vector2i.ONE
		],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85)
	)

	var grid_origin := Vector2(PAD + GUTTER_LEFT, PAD + HEADER + GUTTER_TOP)
	var missing := 0

	for column in region.x:
		draw_string(
			font,
			Vector2(grid_origin.x + column * TILE_PX + 2.0, grid_origin.y - 4.0),
			str(region_origin.x + column),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim
		)

	for row in region.y:
		draw_string(
			font,
			Vector2(PAD, grid_origin.y + row * TILE_PX + TILE_PX * 0.5 + 3.0),
			str(region_origin.y + row),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim
		)

		for column in region.x:
			var offset := Vector2i(column, row)
			var coords := region_origin + offset
			var cell := Rect2(grid_origin + Vector2(column, row) * TILE_PX, Vector2(TILE_PX, TILE_PX))

			var exists := source != null and source.texture != null and source.has_tile(coords)
			if exists:
				draw_texture_rect_region(source.texture, cell, Rect2(source.get_tile_texture_region(coords)))
			else:
				draw_rect(cell, Color(0.55, 0.16, 0.16, 0.35), true)
				if names.has(offset):
					missing += 1

			draw_rect(cell, grid_line, false, 1.0)

			if not names.has(offset):
				continue
			var label := _short_name(names[offset])
			# Shadowed so it stays readable over whatever the art happens to be.
			draw_string(font, cell.position + Vector2(3.0, TILE_PX - 3.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.85))
			draw_string(font, cell.position + Vector2(2.0, TILE_PX - 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.92))

	var footer_y := grid_origin.y + region.y * TILE_PX + 11.0
	if missing > 0:
		draw_string(
			font,
			Vector2(PAD, footer_y),
			"%d piece(s) not drawn in source %d yet -- falling back" % [missing, source_id],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.55, 0.45)
		)


## "Corner Top Left" -> "Cnr TL", so a name still fits on a 40px cell.
static func _short_name(full: String) -> String:
	var head := full
	var tail := ""
	for prefix in ABBREVIATIONS:
		if full.begins_with(prefix):
			head = ABBREVIATIONS[prefix]
			tail = full.substr(prefix.length()).strip_edges()
			break

	var initials := ""
	for word in tail.split(" ", false):
		initials += word.substr(0, 1)
	return head if initials.is_empty() else "%s %s" % [head, initials]
