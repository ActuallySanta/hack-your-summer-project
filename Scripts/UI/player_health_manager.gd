extends TileMapLayer

const HEALTH_ICON := preload("res://Scenes/UI/health_unit.tscn")

@export var starting_health := 3
@export var tile_width := 48
## Should the player get all their health back when the amount of health changes
@export var health_filled_on_collection := true
var number_health : int
var icons : Array[ Node ]
@onready var extension := $HealthbarExtension

func _ready() -> void:
	number_health = starting_health
	_update_display()
	update_health_amount(starting_health, starting_health)
	GlobalSignals.health_changed.connect(update_health_amount)
	GlobalSignals.health_extended_by_one.connect(extend_health_bar)

## Debug tooling
#func _process(delta: float) -> void:
	#if Input.is_action_just_pressed( "Attack" ):
		#extend_health_bar()
	#if Input.is_action_just_pressed("Crouch"):
		#update_health_amount(1, number_health)
	#elif Input.is_action_just_pressed("Jump"):
		#full_heal()

func full_heal() -> void:
	update_health_amount(number_health, number_health)

func update_health_amount(current_health: int, max_health: int) -> void:
	for i in number_health:
		var icon = icons[ i ]
		icon.make_alive(true if i < current_health else false)

func extend_health_bar() -> void:
	number_health += 1
	_update_display()

func _update_display() -> void:
	# Move the extension
	var num_tiles = (number_health + 1) / 2
	extension.global_position.x = tile_width * num_tiles
	
	# Extend the bar
	var pattern : TileMapPattern = tile_set.get_pattern(0)
	for i in num_tiles:
		set_pattern(Vector2i(i,0), pattern)
		
	# Add the health
	while icons.size() < number_health:
		_add_icon()
	
	var inactive_icons : Array[ Node ]
	var active_icons := 0
	for icon in icons:
		if not icon.is_active():
			inactive_icons.append(icon)
		else:
			active_icons += 1
	
	for i in number_health - active_icons:
		inactive_icons[ i ].make_alive( false )
	
	if health_filled_on_collection:
		full_heal()

func _add_icon() -> void:
	var cols = icons.size() / 2
	var horizontal_offset = 7 * icons.size() + 2
	var icon_top := HEALTH_ICON.instantiate()
	var icon_bottom := HEALTH_ICON.instantiate()
	icon_top.global_position += Vector2( horizontal_offset, 2 )
	icon_bottom.global_position += Vector2( horizontal_offset, 14 )
	add_child( icon_top )
	add_child( icon_bottom )
	icons.append( icon_top )
	icons.append( icon_bottom )
