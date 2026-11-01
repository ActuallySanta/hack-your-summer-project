class_name GameHUD
extends CanvasLayer

enum MenuType { MainMenu, GameOver, GameComplete, Pause }

signal death_screen_fade_complete(fade_in : bool)
signal start_new_game()
signal load_game(ignore_custom_save : bool)
signal resume_game()
signal quit_game()

@onready var death_screen: Control = $DeathScreen
@onready var main_menu: Menu = $"Main Menu"
@onready var game_over_menu: EndMenu = $"Game Over Menu"
@onready var game_complete_menu: EndMenu = $"Game Complete Menu"
@onready var player_hud : PlayerHUD = $"Player HUD Layer/Player HUD"
@onready var transition_fade : RoomTransitionFade = $"Player HUD Layer/Player HUD/TransitionFade"
@onready var menus: Array[Control] = [main_menu, game_over_menu, game_complete_menu ]
@export var death_screen_fade_time := 1.5

var death_fade_timer: SceneTreeTimer
var death_fade_in: bool


func _ready() -> void:
	death_screen.modulate.a = 0
	#pass-through menu signals
	main_menu.start_game_pressed.connect(start_new_game.emit)
	main_menu.load_game_pressed.connect(load_game.emit)
	main_menu.quit_game_pressed.connect(quit_game.emit)
	game_over_menu.load_game_pressed.connect(load_game.emit.bind(true))
	game_over_menu.quit_game_pressed.connect(quit_game.emit)
	game_complete_menu.load_game_pressed.connect(load_game.emit)
	game_complete_menu.quit_game_pressed.connect(quit_game.emit)

	game_over_menu.go_to_main_menu.connect(show_menu.bind(MenuType.MainMenu))
	game_complete_menu.go_to_main_menu.connect(show_menu.bind(MenuType.MainMenu))

func _process(_delta: float) -> void:
	if death_fade_timer:
		death_screen.modulate.a = death_fade_timer.time_left / death_screen_fade_time
		if death_fade_in:
			death_screen.modulate.a = 1 - death_screen.modulate.a

## Blacks the screen out the moment a game is asked for, so none of the load is seen.
## The load screen is the room transition's own fade, see [method RoomTransitionFade.cover].
func show_load_screen() -> void:
	transition_fade.cover()

## Fades in on the game that has just been put up, at the rate a room transition clears.
func hide_load_screen() -> void:
	transition_fade.fade_in()

func fade_in_death_screen() -> void:
	death_fade_timer = get_tree().create_timer(death_screen_fade_time)
	death_fade_in = true
	death_fade_timer.timeout.connect(func (): 
		death_screen.modulate.a = 1
		death_screen_fade_complete.emit(true))

func fade_out_death_screen() -> void:
	death_fade_timer = get_tree().create_timer(death_screen_fade_time)
	death_fade_in = false
	death_fade_timer.timeout.connect(func ():
		death_screen.modulate.a = 0
		death_screen_fade_complete.emit(false))

func show_menu(type: MenuType) -> void:
	hide_menus()
	menus[type].visible = true

func hide_menus() -> void:
	for item in menus:
		item.visible = false
	
