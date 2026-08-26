class_name GameHUD
extends CanvasLayer

enum MenuType { MainMenu, GameOver, GameComplete, Pause }

signal death_screen_fade_complete(fade_in : bool)
signal start_new_game()
signal load_game(ignore_custom_save : bool)
signal resume_game()
signal quit_game()

@onready var loading_screen: Control = $LoadingScreen
@onready var death_screen: Control = $DeathScreen
@onready var main_menu: Menu = $"Main Menu"
@onready var game_over_menu: EndMenu = $"Game Over Menu"
@onready var game_complete_menu: EndMenu = $"Game Complete Menu"
@onready var pause_menu : PauseMenu = $"Pause Menu"
@onready var player_hud : PlayerHUD = $"Player HUD"
@onready var menus: Array[Control] = [main_menu, game_over_menu, game_complete_menu, pause_menu]

@export var load_screen_fade_time := 0.8
@export var death_screen_fade_time := 1.5

var load_fade_timer: SceneTreeTimer
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
	pause_menu.resume_pressed.connect(resume_game.emit)
	pause_menu.restart_pressed.connect(load_game.emit)
	pause_menu.quit_pressed.connect(quit_game.emit)

	game_over_menu.go_to_main_menu.connect(show_menu.bind(MenuType.MainMenu))
	game_complete_menu.go_to_main_menu.connect(show_menu.bind(MenuType.MainMenu))
	pause_menu.main_menu_pressed.connect(show_menu.bind(MenuType.MainMenu))

func _process(_delta: float) -> void:
	if load_fade_timer:
		loading_screen.modulate.a = load_fade_timer.time_left / load_screen_fade_time
	if death_fade_timer:
		death_screen.modulate.a = death_fade_timer.time_left / death_screen_fade_time
		if death_fade_in:
			death_screen.modulate.a = 1 - death_screen.modulate.a

func show_load_screen() -> void:
	loading_screen.modulate.a = 1

func hide_load_screen(fade := true) -> void:
	if fade:
		load_fade_timer = get_tree().create_timer(load_screen_fade_time)
		load_fade_timer.timeout.connect(hide_load_screen.bind(false))
	else:
		loading_screen.modulate.a = 0

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

## Puts the full map away at once. Called when the game pauses, so the map cannot sit
## over the pause menu -- a paused tree would freeze its closing animation part-way.
func force_close_map() -> void:
	if is_instance_valid(player_hud):
		player_hud.force_close_map()

func hide_menus() -> void:
	for item in menus:
		item.visible = false
	
