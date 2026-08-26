## The health bar.
##
## The bar is [i]derived[/i] from the (current, maximum) pair the player reports, not
## accumulated from events. It used to keep its own [member number_health] counter
## that only ever went up, on [code]health_extended_by_one[/code], and nothing reset
## it: loading a save with extenders already collected left the bar at three, and
## reloading after collecting one left the bar a heart longer than the player's actual
## maximum. Reading both numbers off the one signal means the bar cannot disagree with
## the player about how much health they have.
extends TileMapLayer

const HEALTH_ICON := preload("res://Scenes/UI/health_unit.tscn")

## Health shown before the player has reported anything (the menu).
@export var starting_health := 3
@export var tile_width := 48
## Two icons are stacked per bar tile, so the backing tiles grow half as fast as the
## icons do.
const ICONS_PER_TILE := 2
## Horizontal gap between icons in a column pair, in pixels.
const ICON_SPACING := 7

var number_health : int
var icons : Array[ Node ]
## How many backing tiles are currently drawn, so shrinking the bar can rub out the
## ones that are no longer under anything.
var _drawn_tiles : int
@onready var extension := $HealthbarExtension

func _ready() -> void:
	number_health = -1
	update_health_amount(starting_health, starting_health)
	GlobalSignals.health_changed.connect(update_health_amount)

## Paints the bar for [param current_health] out of [param max_health], resizing it
## first if the maximum has moved.
func update_health_amount(current_health: int, max_health: int) -> void:
	_resize_bar(max_health)
	for i in icons.size():
		var icon = icons[ i ]
		# Icons past the current maximum are left over from a longer bar. They are
		# hidden rather than freed, so a reload that puts the length back does not
		# have to rebuild them.
		icon.visible = i < number_health
		if icon.visible:
			icon.make_alive( i < current_health )

func full_heal() -> void:
	update_health_amount( number_health, number_health )

func _resize_bar(new_max: int) -> void:
	new_max = maxi( new_max, 0 )
	if new_max == number_health:
		return
	number_health = new_max
	while icons.size() < number_health:
		_add_icon()
	_update_display()

func _update_display() -> void:
	var num_tiles : int = ceili( float( number_health ) / ICONS_PER_TILE )
	extension.global_position.x = tile_width * num_tiles

	var pattern : TileMapPattern = tile_set.get_pattern(0)
	for i in num_tiles:
		set_pattern( Vector2i(i, 0), pattern )
	# Rub out any tiles the bar has shrunk past, or they stay on screen under nothing.
	# The pattern's own height is used, so a bar drawn from a taller pattern clears.
	var pattern_size := pattern.get_size()
	for i in range( num_tiles, _drawn_tiles ):
		for row in maxi( pattern_size.y, 1 ):
			erase_cell( Vector2i(i, row) )
	_drawn_tiles = num_tiles

## Icons go on in columns of two, so each call adds a pair.
func _add_icon() -> void:
	var horizontal_offset := ICON_SPACING * icons.size() + 2
	var icon_top := HEALTH_ICON.instantiate()
	var icon_bottom := HEALTH_ICON.instantiate()
	icon_top.position += Vector2( horizontal_offset, 2 )
	icon_bottom.position += Vector2( horizontal_offset, 14 )
	add_child( icon_top )
	add_child( icon_bottom )
	icons.append( icon_top )
	icons.append( icon_bottom )
