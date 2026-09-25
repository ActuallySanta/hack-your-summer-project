extends TextDisplay

const hover_sfx := preload("res://Sounds/UI/menuHover.wav")
const click_sfx := preload("res://Sounds/UI/menuSelect.wav")

## Pixels the list travels per notch of the mouse wheel
@export_group("Scrolling")
@export var scroll_speed : float = 20.0
@export var scroll_update_speed : float = 400.0
@export_group("Rest Positions")
@export var hidden_pos : float = -410
@export var shown_pos : float = 0
@export var panel_move_speed : float = 1800.0

const WIDTH := 15
## How many lines of text fit on screen at once
const DISPLAY_HEIGHT := 28

## The longest real step the panel will take in one frame. A load hitch is not travel, and without
## this the menu would jump the width of the screen on the frame the game comes back.
const MAX_REAL_DELTA := 0.1

enum MenuState { MENU_REST_HIDDEN, MENU_REST_SHOWN, MENU_MOVE_TO_HIDDEN, MENU_MOVE_TO_SHOWN }

@onready var audio_source : AudioStreamPlayer2D = $AudioStreamPlayer2D

var stream_playback : AudioStreamPlaybackPolyphonic

## One line of the list in screen pixels, the node's scale included
var line_height : float:
	get():
		return tile_set.tile_size.y * scale.y

## The furthest up the list may travel, which is the point where its last line rests on the bottom
## row of the screen. Never positive: a list shorter than the screen has nowhere to go.
var scroll_lower_bound : float:
	get():
		return minf(0.0, -(root.total_height - DISPLAY_HEIGHT) * line_height)

var scroll_offset : float:
	set(new_value):
		scroll_offset = clampf(new_value, scroll_lower_bound, 0.0)

var scroll_actual : float:
	get():
		return scroll_offset# - line_height * 2

var root : TextListItem
var menu_goal : MenuState:
	set(new_value):
		menu_goal = (new_value % 2) as MenuState
var goal_pos : float:
	get(): return hidden_pos if menu_goal == MenuState.MENU_REST_HIDDEN else shown_pos
var goal_dir : float:
	get(): return -1 if menu_goal == MenuState.MENU_REST_HIDDEN else 1

var menu_state : MenuState:
	set(new_value):
		menu_state = new_value
		if menu_state == MenuState.MENU_REST_HIDDEN:
			position.x = hidden_pos
		elif menu_state == MenuState.MENU_REST_SHOWN:
			position.x = shown_pos

var menu_open_percent : float:
	get(): return 1 - position.x / hidden_pos
var inverse_percent : float:
	get(): return clamp(1 - menu_open_percent, 0.01, 0.9)

## Whether the list is taking the cursor. Any part of the panel being on screen is enough: what
## the mouse is over is worked out from where the panel actually is, so a row half way in is still
## a row the player can see and point at, and making them wait out the slide would read as the
## menu ignoring them. Only a panel fully away has nothing to click.
var touchable : bool:
	get(): return menu_state != MenuState.MENU_REST_HIDDEN

## Whether the menu is the one currently slowing the world down. It takes the clock on the way out
## and gives it back the moment it is fully away, so a world nobody is holding is left alone.
var _owns_world_clock : bool = false
## What PlayerManager.canMove was before the menu borrowed it
var _player_could_move := true
## The real clock, read straight rather than through a delta the menu itself is shrinking
var _real_time_usec : int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_state = MenuState.MENU_REST_HIDDEN
	menu_goal = MenuState.MENU_REST_HIDDEN
	_real_time_usec = Time.get_ticks_usec()
	_open_audio_mixer()

	var options = TextListItem.new("Options", WIDTH, [
		TextListItem.new("Visuals", WIDTH, []),
		TextListItem.new("Audio", WIDTH, []),
		TextListItem.new("Controls", WIDTH, []),
		TextListItem.new("Difficulty", WIDTH, []),
	])
	var logbook = TextListItem.new("Log Book", WIDTH, [
		TextListItem.new("Entities", WIDTH, ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]),
		TextListItem.new("Regions", WIDTH),
		TextListItem.new("General", WIDTH),
	])
	root = TextListItem.new("C:/Users/Ash Jerock/ana4Tl", WIDTH, [ options, logbook, TextListItem.new("Shut Down", WIDTH, ["Confirm:", "Yes", "No"])])
	root.show_children()
	root.parse_path("Shut Down/Yes").on_click.connect( _on_shut_down_confirmed )
	root.parse_path("Shut Down/No").on_click.connect( _on_shut_down_declined )
	root.display_list( self )

## Time is global, and this node is one of the two things that takes it away, so a menu going down
## with the game still stopped would leave the world frozen with nothing left to thaw it.
func _exit_tree() -> void:
	if _owns_world_clock:
		Engine.time_scale = 1.0

func _process(_delta: float) -> void:
	var delta := _real_delta()	# Not the delta handed in: see _real_delta()
	update_scroll( delta )
	update_state( delta )
	update_world_time()
	update_hover()
	if not root.dirty: return
	root.dirty = false
	root.display_clear( self )
	root.display_list( self )
	scroll_offset = scroll_offset	# The list just changed height, so re-clamp in case it shrank out from under us

func update_state(delta: float) -> void:
	$Seperater.do_update = true if touchable else false
	if menu_goal == menu_state:
		return
		
	menu_state = MenuState.MENU_MOVE_TO_HIDDEN if menu_state == MenuState.MENU_REST_HIDDEN else MenuState.MENU_MOVE_TO_SHOWN
	var d = delta * panel_move_speed
	d *= goal_dir * inverse_percent
	if abs(d) > abs(position.x - goal_pos):
		position.x = goal_pos
		menu_state = menu_goal
		return
	position.x += d

#region Opening and closing
func open_menu() -> void:
	if menu_goal == MenuState.MENU_REST_SHOWN: return
	if not _owns_world_clock and not is_equal_approx(Engine.time_scale, 1.0): return

	menu_goal = MenuState.MENU_REST_SHOWN
	_owns_world_clock = true
	_set_player_frozen( true )

func close_menu() -> void:
	if menu_goal == MenuState.MENU_REST_HIDDEN: return
	menu_goal = MenuState.MENU_REST_HIDDEN

func update_world_time() -> void:
	if not _owns_world_clock: return
	Engine.time_scale = clampf(1.0 - menu_open_percent, 0.0, 1.0)
	if menu_state != MenuState.MENU_REST_HIDDEN: return

	_owns_world_clock = false
	_set_player_frozen( false )

func _set_player_frozen(frozen: bool) -> void:
	PlayerManager.canMove = !frozen
	if is_instance_valid(PlayerManager.player): PlayerManager.player.reset_all_inputs()

## Seconds since the last frame off the real clock, which is not what _process is handed. The menu
## slows the world to a stop as it opens, and a slide counted in a delta it was shrinking itself
## would crawl and never arrive - the same reason [RoomTransitionFade] times itself this way.
func _real_delta() -> float:
	var now := Time.get_ticks_usec()
	var elapsed := (now - _real_time_usec) / 1000000.0
	_real_time_usec = now
	return minf(elapsed, MAX_REAL_DELTA)
#endregion

func update_scroll(delta: float) -> void:
	var p_y = position.y
	if position.y == scroll_actual: return
		
	var d = scroll_update_speed * delta * (-1 if p_y > scroll_actual else 1)
	if abs(d) > abs(position.y - scroll_actual):
		position.y = scroll_actual
		return
	d *= max(0.1, abs(position.y - scroll_actual)/20)
	position.y += d

## Whether the cursor is inside the list's panel on screen, which is not the same question as whether
## a list line sits under it: scrolled to the bottom the last lines still leave empty rows below them,
## and the wheel has to keep working there. Claiming the wheel by panel is also what lets the pop-up
## beside the list scroll on its own without either one counter-scrolling the other.
func mouse_over_display(tile_coords: Vector2i) -> bool:
	if tile_coords.x < 0 or tile_coords.x >= WIDTH:
		return false
	var top_row : int = floori(-position.y / line_height)
	return tile_coords.y >= top_row and tile_coords.y < top_row + DISPLAY_HEIGHT

func mouse_tile_coords() -> Vector2i: return local_to_map( to_local( get_global_mouse_position() ) )

func update_hover() -> void:
	if not touchable:
		root.on_mouse_exited()
		root.cancel_press()
		return

	var was_hovering := root.hovered_item
	var tile_coords := mouse_tile_coords()
	if mouse_over_display( tile_coords ): root.on_mouse_moved( tile_coords )
	else: root.on_mouse_exited()

	if root.hovered_item != null and root.hovered_item != was_hovering: play_sfx( hover_sfx )

func _input(event: InputEvent) -> void:
	if not touchable or not event is InputEventMouseButton: return

	var tile_coords := mouse_tile_coords()
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if root.on_mouse_released( tile_coords ): play_sfx( click_sfx )
		return

	if not event.pressed or not mouse_over_display( tile_coords ): return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP: scroll_offset += scroll_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: scroll_offset -= scroll_speed
	elif event.button_index == MOUSE_BUTTON_LEFT: root.on_mouse_pressed( tile_coords )

#region Audio
func _open_audio_mixer() -> void:
	audio_source.play()
	stream_playback = audio_source.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if stream_playback == null: printerr("WARNING (list_display _open_audio_mixer): ", audio_source.name, " needs an AudioStreamPolyphonic as its stream, so the list will be silent")

func play_sfx(sfx: AudioStream) -> void:
	if not audio_source.playing: _open_audio_mixer()	# Something stopped the player, so the old playback is deaf now
	if stream_playback == null: return
	stream_playback.play_stream( sfx )
#endregion

#region List actions
func _on_shut_down_confirmed() -> void: get_tree().quit()

func _on_shut_down_declined() -> void:
	root.parse_path("Shut Down").hide_children()
	root.dirty = true
#endregion
