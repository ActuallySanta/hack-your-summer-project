## The screen-space home of the list menu.
##
## The menu itself is a [TileMapLayer], and a tile map is part of the world: left on its own it is
## drawn at the world's origin and abandoned there the moment the camera walks away, which is the
## whole reason this node exists. A [CanvasLayer] pins its contents to the screen instead, and
## hands the panel a mouse position in screen space while it is at it, so the cursor lands on the
## row it is pointing at wherever in the world the player happens to be standing.
##
## The layer sits above the game's HUD (1) and its menus (2) and below the loading screen (10),
## because for as long as this is on screen it is the thing being read.
##
## Everything the menu actually does lives on the panel; this only carries the controls through.
extends CanvasLayer

@onready var panel := $Panel

func toggle_menu() -> void:
	panel.toggle_menu()

func open_menu() -> void:
	panel.open_menu()

func close_menu() -> void:
	panel.close_menu()

func is_open() -> bool:
	return panel.touchable
