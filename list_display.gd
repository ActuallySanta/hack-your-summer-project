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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# The menu is what hands the world's clock back, so it must not be something a stopped world stops.
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
	root = TextListItem.new("C:/Users/Ash Jerock/ana7Tl", WIDTH, [ options, logbook, TextListItem.new("Shut Down", WIDTH, ["Confirm:", "Yes", "No"])])
	root.show_children()
	_hook_up_labels()
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
## Puts the menu away if it is coming out, and brings it out otherwise. Called part way through a
## slide this reverses it from where it got to, which is why the goal is what gets set rather than
## the position: the travel and the world's clock both read off where the panel actually is.
func toggle_menu() -> void:
	if menu_goal == MenuState.MENU_REST_SHOWN: close_menu()
	else: open_menu()

func open_menu() -> void:
	if menu_goal == MenuState.MENU_REST_SHOWN: return
	if not _owns_world_clock and not _world_clock_is_free(): return

	menu_goal = MenuState.MENU_REST_SHOWN
	_owns_world_clock = true
	_set_player_frozen( true )

func close_menu() -> void:
	if menu_goal == MenuState.MENU_REST_HIDDEN: return
	menu_goal = MenuState.MENU_REST_HIDDEN

## Hands the world's clock to the panel's own travel, so the game slows to a stop exactly as the
## menu arrives and picks its speed back up as the menu leaves - the deceleration is the slide's
## own easing curve, not a second animation that has to be kept in step with it.
## Inverted the way [RoomTransitionFade] does it: a menu fully out is a world fully stopped.
func update_world_time() -> void:
	if not _owns_world_clock: return
	Engine.time_scale = clampf(1.0 - menu_open_percent, 0.0, 1.0)
	if menu_state != MenuState.MENU_REST_HIDDEN: return

	# Home again, and the write above was the one that put time back to 1, so let go of both the
	# clock and the player rather than sitting on a world nobody is using.
	_owns_world_clock = false
	_set_player_frozen( false )

## Whether the world's clock is free to take. Time is global and the room fade drives it too, so
## the menu keeps out of a world that is already being slowed instead of the two of them writing
## over each other every frame - which ends with one handing the world back at full speed while
## the other still has the screen.
func _world_clock_is_free() -> bool:
	return is_equal_approx(Engine.time_scale, 1.0)

## Takes the player's input away for as long as the menu is up, the way the full map does it. The
## world being stopped is not enough on its own: _process still runs at a time scale of zero, so
## the keys pressed while reading the menu would otherwise all go off the moment time came back.
func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		_player_could_move = PlayerManager.canMove
		PlayerManager.canMove = false
	else:
		PlayerManager.canMove = _player_could_move

	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.reset_all_inputs()

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
	if position.y == scroll_actual:
		return
		
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
	var top_row : int = floori(-position.y / line_height)	# The list line currently drawn on the top row of the screen
	return tile_coords.y >= top_row and tile_coords.y < top_row + DISPLAY_HEIGHT

## The list line the cursor is on, which is not a screen row: the node carries the scroll and the
## slide in its own position, so going through to_local() is what keeps the two in step.
func mouse_tile_coords() -> Vector2i:
	return local_to_map( to_local( get_global_mouse_position() ) )

## Keeps the hover under the cursor. This is a per frame job rather than a mouse motion one because
## the list moves as much as the cursor does: scrolling and sliding both change what a still cursor
## is pointing at.
func update_hover() -> void:
	if not touchable:
		root.on_mouse_exited()
		root.cancel_press()
		return

	var was_hovering := root.hovered_item
	var tile_coords := mouse_tile_coords()
	if mouse_over_display( tile_coords ): root.on_mouse_moved( tile_coords )
	else: root.on_mouse_exited()

	# Only the moment the cursor lands on a new row is worth a sound. This runs every frame, so
	# playing on "the cursor is over something" would fire sixty times a second into the mixer.
	if root.hovered_item != null and root.hovered_item != was_hovering:
		play_sfx( hover_sfx )

func _input(event: InputEvent) -> void:
	if not touchable or not event is InputEventMouseButton:
		return

	var tile_coords := mouse_tile_coords()
	# A release is taken wherever it happens, so a press dragged off the list is called off rather
	# than left stuck down waiting for a button that already came up.
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if root.on_mouse_released( tile_coords ): play_sfx( click_sfx )	# Silence is the right answer for a click that was called off, or one on inert text
		return

	if not event.pressed or not mouse_over_display( tile_coords ):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_offset += scroll_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_offset -= scroll_speed
	elif event.button_index == MOUSE_BUTTON_LEFT:
		root.on_mouse_pressed( tile_coords )

#region Audio
## Starts the one stream the list's sounds all ride on. An AudioStreamPolyphonic makes no sound of
## its own - it is an empty mixer with room for several voices - so the player has to be playing it
## before there is a playback to hand sounds to, and get_stream_playback() answers null until then.
## The player is then left running for the node's whole life; nothing here ever calls play() again.
func _open_audio_mixer() -> void:
	audio_source.play()
	stream_playback = audio_source.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if stream_playback == null:
		printerr("WARNING (list_display _open_audio_mixer): ", audio_source.name, " needs an AudioStreamPolyphonic as its stream, so the list will be silent")

## Feeds [param sfx] into the mixer as a voice of its own, which is the point of the polyphonic
## stream: a click landing while a hover is still ringing lays over it instead of cutting it off,
## the way a plain player calling play() twice would.
func play_sfx(sfx: AudioStream) -> void:
	if not audio_source.playing: _open_audio_mixer()	# Something stopped the player, so the old playback is deaf now
	if stream_playback == null: return
	stream_playback.play_stream( sfx )
#endregion

#region List actions
## Gives the labels that do something someone to tell. A label with nothing listening is inert by
## design - it takes no hover, no click and no rule - so this is also the list of what the menu
## can currently be asked to do, and every other label is waiting on the screen it will open.
func _hook_up_labels() -> void:
	root.parse_path("Shut Down/Yes").on_click.connect( _on_shut_down_confirmed )
	root.parse_path("Shut Down/No").on_click.connect( _on_shut_down_declined )

func _on_shut_down_confirmed() -> void:
	get_tree().quit()

## Folds the group back up, so the question goes away along with the answer
func _on_shut_down_declined() -> void:
	root.parse_path("Shut Down").hide_children()
	root.dirty = true
#endregion
