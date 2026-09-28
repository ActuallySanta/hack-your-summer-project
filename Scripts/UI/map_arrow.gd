@tool
## One of the arrows round the edge of the [PauseMap]. It lights up while the map is
## being panned its way: its movement key is held, or the mouse is dragging the map,
## which lights all four.
##
## Must be a direct child of the map. It keeps itself in the middle of its [member edge]
## using the texture's own size, so crop each texture to the arrow with no padding. It
## needs a z_index over 5 to draw above the MetSys map (borders 1-2, custom elements 3,
## player location 5), and under 8 to stay behind the turn-on beam.
class_name MapArrow
extends Sprite2D

enum Edge { NORTH, SOUTH, WEST, EAST }

# Indexed by Edge.
const _OUTWARD := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Which edge of the map the arrow sits in the middle of.
@export var edge := Edge.NORTH:
	set(value):
		edge = value
		_place()

## Shown while the map isn't being panned this way.
@export var idle_texture: Texture2D:
	set(value):
		idle_texture = value
		_refresh()

## Shown while it is.
@export var pressed_texture: Texture2D:
	set(value):
		pressed_texture = value
		_refresh()

## Empty pixels left between the arrow and the map's edge while it is pressed.
@export var edge_margin := 3:
	set(value):
		edge_margin = value
		_place()

## Pixels the arrow moves out towards its edge while pressed, so a resting arrow sits
## [code]edge_margin + press_offset[/code] from the edge.
@export var press_offset := 1:
	set(value):
		press_offset = value
		_place()

## Whether the arrow is showing as pressed. The map drives this while the game runs.
var pressed := false:
	set(value):
		if value == pressed:
			return
		pressed = value
		_refresh()

func _ready() -> void:
	# _place() works from the top-left corner.
	centered = false
	var map := get_parent() as Control
	if map:
		map.resized.connect(_place)
	if map is PauseMap and not Engine.is_editor_hint():
		map.pan_input_changed.connect(_on_pan_input_changed)
	_refresh()

func _refresh() -> void:
	texture = pressed_texture if pressed and pressed_texture else idle_texture
	_place()

func _place() -> void:
	var map := get_parent() as Control
	if not is_node_ready() or not map or not texture:
		return

	var area := map.size
	var arrow := texture.get_size()
	var inset := float(edge_margin + (0 if pressed else press_offset))
	# Floored so an odd leftover never puts the arrow on a half pixel.
	var middle := ((area - arrow) * 0.5).floor()
	match edge:
		Edge.NORTH:
			position = Vector2(middle.x, inset)
		Edge.SOUTH:
			position = Vector2(middle.x, area.y - inset - arrow.y)
		Edge.WEST:
			position = Vector2(inset, middle.y)
		Edge.EAST:
			position = Vector2(area.x - inset - arrow.x, middle.y)

func _on_pan_input_changed(held: Vector2i, dragging: bool) -> void:
	var outward: Vector2i = _OUTWARD[edge]
	pressed = dragging or held.x * outward.x + held.y * outward.y > 0
