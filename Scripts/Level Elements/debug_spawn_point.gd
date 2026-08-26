@tool
## A place the custom save can drop the player, draggable in the room scene.
##
## The custom save ([member GameManager.use_custom_save]) exists to start the game
## partway in while a room is being worked on. It used to take the position as a pair
## of numbers typed into the inspector on [GameManager], which meant guessing a
## coordinate in a room you were not looking at and running the game to find out where
## it landed.
##
## Drop one of these in the room instead and drag it where you want to start. Give it
## an [member id] and put the same id in [member GameManager.save_spawn_id]; several
## can sit in one room so you can keep a few useful starts and switch between them
## with one word.
##
## These are development scaffolding: nothing but the custom save reads them, and they
## are invisible in a running game.
class_name DebugSpawnPoint
extends Marker2D

const GROUP := &"debug_spawn_point"

## Which spawn this is. [member GameManager.save_spawn_id] names the one to use.
@export var id : StringName = &"default":
	set(value):
		id = value
		update_configuration_warnings()

## Colour of the marker drawn in the editor. Has no effect in game.
@export var editor_colour := Color(0.4, 1.0, 0.6, 0.9):
	set(value):
		editor_colour = value
		queue_redraw()

## Radius of the marker drawn in the editor, in pixels.
@export var editor_radius := 14.0:
	set(value):
		editor_radius = value
		queue_redraw()

func _ready() -> void:
	add_to_group(GROUP)
	if not Engine.is_editor_hint():
		# Marker2D draws its cross in a running game too; nothing here should be seen.
		visible = false

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, editor_radius, Color(editor_colour, 0.25))
	draw_arc(Vector2.ZERO, editor_radius, 0.0, TAU, 24, editor_colour, 2.0)
	# A foot mark, since what is being placed is where the player stands.
	draw_line(Vector2(-editor_radius, 0.0), Vector2(editor_radius, 0.0), editor_colour, 2.0)

func _get_configuration_warnings() -> PackedStringArray:
	if String(id).is_empty():
		return ["Give this spawn point an id, so GameManager.save_spawn_id can name it."]
	return []
