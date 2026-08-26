## In-game HUD: minimap, dialogue box, health, and the full-screen map.
##
## Owns the map toggle. Opening the map starts the [FullMap]'s opening animation and
## the [HudMinimap]'s closing animation at the same time; closing does the reverse.
## Input is ignored while either is still animating, so a half-open map can't be
## toggled out from under its own animation.
##
## For as long as the map is on screen the player is frozen and the movement keys
## scroll the map instead — see [member FullMap.scroll_speed] and the scroll limits.
class_name PlayerHUD
extends Control

## Emitted once the full map has finished opening.
signal map_opened
## Emitted once the full map has finished closing.
signal map_closed

## Input action that toggles the full map.
@export var map_action := &"OpenMap"

## Pauses the scene tree for as long as the full map is on screen. The map, the
## minimap and this node keep processing so the open/close animations still run;
## the rest of the HUD pauses with the game.
@export var pause_while_map_open := false

@onready var minimap: HudMinimap = $Minimap
@onready var full_map: FullMap = $FullMap

## What [code]PlayerManager.canMove[/code] was before the map borrowed it.
var _player_could_move := true

func _ready() -> void:
	if pause_while_map_open:
		_setup_pause_exemptions()

	full_map.opened.connect(map_opened.emit)
	full_map.closed.connect(_on_full_map_closed)

func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed(map_action):
		return
	if full_map.is_animating() or minimap.is_animating():
		return

	if full_map.is_open():
		close_map()
	elif _can_open_map():
		open_map()

func open_map() -> void:
	if pause_while_map_open:
		get_tree().paused = true
	_set_player_frozen(true)
	minimap.close()
	full_map.open()

func close_map() -> void:
	minimap.open()
	full_map.close()

## Puts the map away at once, for the moments something else takes the screen.
##
## The pause menu is the one that matters: pausing stops the tree, so a map closing
## normally would freeze mid-slide and stay on screen over the menu for as long as the
## game was paused. The minimap is snapped back with it so the HUD is whole again the
## moment the game resumes.
func force_close_map() -> void:
	if not (full_map.is_open() or full_map.is_animating()):
		return
	# snap_closed() emits FullMap.closed, which runs _on_full_map_closed for us.
	full_map.snap_closed()
	minimap.open()

## The open map scrolls with the movement keys, so the player has to stop reading
## them for as long as it is on screen — including the inputs already buffered when
## it opened, which [code]handle_inputs()[/code] would otherwise keep acting on.
func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		_player_could_move = PlayerManager.canMove
		PlayerManager.canMove = false
	else:
		PlayerManager.canMove = _player_could_move

	if is_instance_valid(PlayerManager.player):
		PlayerManager.player.reset_all_inputs()

## The map is a full-screen panel, so it stays out of the way of anything else that
## already owns the screen.
func _can_open_map() -> bool:
	if PlayerManager.inDialogue:
		return false

	var game_hud := get_parent() as GameHUD
	if game_hud:
		for menu in game_hud.menus:
			if menu.visible:
				return false
	return true

func _on_full_map_closed() -> void:
	if pause_while_map_open:
		get_tree().paused = false
	_set_player_frozen(false)
	map_closed.emit()

## Keeps this node and the two map panels running while the tree is paused, without
## dragging the rest of the HUD (dialogue, health) along with them.
func _setup_pause_exemptions() -> void:
	for child in get_children():
		if child != minimap and child != full_map:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
