extends TileMapLayer

const HEALTH_ICON := preload("res://Scenes/UI/health_unit.tscn")

@export var starting_health := 3

var number_health : int = -1
var icons : Array[ HealthUnit ]

var cols : int:
	get(): return (icons.size() / 2)

@onready var extension := $HealthbarExtension

func _ready() -> void:
	update_health_amount(starting_health, starting_health)
	GlobalSignals.health_changed.connect( update_health_amount )
	GlobalSignals.max_player_health.connect( full_heal )

func update_health_amount(current_health: int, max_health: int) -> void:
	_resize_bar(max_health)
	for i in icons.size():
		var icon = icons[ i ]
		icon.visible = i < number_health
		if icon.visible: icon.make_alive( i < current_health )

func full_heal() -> void:
	update_health_amount( number_health, number_health )

func _resize_bar(new_max: int) -> void:
	if new_max == number_health: return
	number_health = new_max
	while icons.size() < number_health: _add_icon()
	extension.position.x = HealthUnit.PIXELS_WIDE_TOTAL * ((icons.size()-1) / 2)

func _add_icon() -> void:
	var horizontal_offset := HealthUnit.PIXELS_WIDE_TOTAL * cols + HealthUnit.PIXELS_SPACE
	var vertical_offset := HealthUnit.PIXELS_SPACE if icons.size() % 2 == 0 else HealthUnit.PIXELS_SPACE + HealthUnit.PIXELS_TALL_TOTAL
	var icon := HEALTH_ICON.instantiate()
	icon.position += Vector2( horizontal_offset, vertical_offset )
	add_child( icon )
	icons.append( icon )
