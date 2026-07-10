class_name GameHUD
extends CanvasLayer

@onready var loading_screen: Control = $LoadingScreen

@export var load_screen_fade_time := 0.8

@onready var load_fade_timer: SceneTreeTimer

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if load_fade_timer:
		loading_screen.modulate.a = load_fade_timer.time_left / load_screen_fade_time

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
