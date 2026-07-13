class_name GameHUD
extends CanvasLayer

signal death_screen_fade_complete(fade_in : bool)

@onready var loading_screen: Control = $LoadingScreen
@onready var death_screen: Control = $DeathScreen

@export var load_screen_fade_time := 0.8
@export var death_screen_fade_time := 1.5

var load_fade_timer: SceneTreeTimer
var death_fade_timer: SceneTreeTimer
var death_fade_in: bool

func _ready() -> void:
	death_screen.modulate.a = 0

func _process(_delta: float) -> void:
	if load_fade_timer:
		loading_screen.modulate.a = load_fade_timer.time_left / load_screen_fade_time
	if death_fade_timer:
		death_screen.modulate.a = death_fade_timer.time_left / death_screen_fade_time
		if death_fade_in:
			death_screen.modulate.a = 1 - death_screen.modulate.a

func show_load_screen() -> void:
	print("Showing load screen")
	loading_screen.modulate.a = 1

func hide_load_screen(fade := true) -> void:
	if fade:
		print("Fading load screen")
		load_fade_timer = get_tree().create_timer(load_screen_fade_time)
		load_fade_timer.timeout.connect(hide_load_screen.bind(false))
	else:
		print("Hiding load screen")
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
