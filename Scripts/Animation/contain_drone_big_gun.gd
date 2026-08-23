class_name CDBigGun extends Node2D

const ANIM_FRAME_TIME_SECONDS := 0.1

@export var shoot_timer := 5

@onready var barrel := $BIGGUNBarrel
@onready var flare := $BIGGUNFlare
@onready var shooter := $Shoot
@onready var shooter_visual := $Shoot/BIGGUNSHOOT

var anim_speed_adjust : float:
	set(value):
		anim_speed_adjust = value
		barrel.anim_speed_adjust = value
		flare.anim_speed_adjust = value
		shooter_visual.anim_speed_adjust = value

var timer : float = 0
var anim_state : int = 0

func make_paused(value: bool) -> void:
	barrel.make_paused(value)
	flare.make_paused(value)
	shooter_visual.make_paused(value)

func iterate() -> void:
	match anim_state:
		1: # 1: turn on flare
			turn_on_flare()
			timer += ANIM_FRAME_TIME_SECONDS
			anim_state = 2
		2: # 2: turn on shooter
			turn_on_shooter()
			timer += shoot_timer
			anim_state = 3
		3:# 3: Idle firing
			turn_off_gun()
		4: # 4: turn on flare
			turn_on_flare()
			timer += ANIM_FRAME_TIME_SECONDS
			anim_state = 5
		5: # 5: turn on barrel
			turn_on_barrel()
			timer = 0
			anim_state = 0

func _process(delta: float) -> void:
	if anim_state == 0: # 0: Idle
		return
	
	timer -= delta
	while timer <= 0:
		iterate()

func turn_on_gun() -> void:
	anim_state = 1

func turn_off_gun() -> void:
	anim_state = 4

func turn_on_barrel() -> void:
	flare.visible = false
	shooter.visible = false
	barrel.visible = true

func turn_on_flare() -> void:
	flare.z_index = 0
	shooter.z_index = -1000
	flare.visible = true
	shooter.visible = true
	barrel.visible = false

func turn_on_shooter() -> void:
	shooter.z_index = 0
	flare.z_index = -1000
	shooter.visible = true
	barrel.visible = false
