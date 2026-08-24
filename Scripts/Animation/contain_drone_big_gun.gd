class_name CDBigGun extends Node2D

const ANIM_FRAME_TIME_SECONDS := 0.1

## Seconds to hold the beam once it is up. Values <= 0 hold it until something
## calls turn_off_gun() or turn_on_barrel(); for the charge attack that is
## _on_enter_tunnel(), so the beam lasts exactly as long as the charge does.
@export var shoot_timer : float = 0.0

@onready var barrel := $BIGGUNBarrel
@onready var flare := $BIGGUNFlare
@onready var shooter := $Shoot
@onready var shooter_visual := $Shoot/BIGGUNSHOOT
@onready var hitbox := $Hitbox
#sex
@onready var hummer := $Hummer
@onready var boomer := $Boomer

enum anim {
	IDLE,			# 0: nothing to do
	OPEN_FLARE,		# 1: muzzle flare on the way up
	OPEN_SHOOTER,	# 2: beam on
	FIRING,			# 3: holding the beam
	CLOSE_FLARE,	# 4: muzzle flare on the way down
	CLOSE_BARREL,	# 5: back to the resting barrel
}

var anim_speed_adjust : float:
	set(value):
		anim_speed_adjust = value
		barrel.anim_speed_adjust = value
		flare.anim_speed_adjust = value
		shooter_visual.anim_speed_adjust = value

var timer : float = 0
var anim_state : anim = anim.IDLE

func _ready() -> void:
	hitbox.ignore_hits = true
	hummer.volume_db = -80

func make_paused(value: bool) -> void:
	barrel.make_paused(value)
	flare.make_paused(value)
	shooter_visual.make_paused(value)

func iterate() -> void:
	match anim_state:
		anim.OPEN_FLARE:
			turn_on_flare()
			timer += ANIM_FRAME_TIME_SECONDS
			anim_state = anim.OPEN_SHOOTER
		anim.OPEN_SHOOTER:
			turn_on_shooter()
			# INF parks the timer so FIRING never times out on its own; whoever
			# started the gun decides when it stops.
			timer += shoot_timer if shoot_timer > 0.0 else INF
			anim_state = anim.FIRING
		anim.FIRING:
			turn_off_gun()
		anim.CLOSE_FLARE:
			turn_on_flare()
			timer += ANIM_FRAME_TIME_SECONDS
			anim_state = anim.CLOSE_BARREL
		anim.CLOSE_BARREL:
			turn_on_barrel()

func _process(delta: float) -> void:
	if anim_state == anim.IDLE:
		return
	
	timer -= delta
	# Every branch of iterate() either pushes the timer forward or drops to
	# IDLE, so the IDLE check is what guarantees this loop terminates. Without
	# it, CLOSE_BARREL (timer = 0, state = IDLE) re-enters iterate() with a
	# state that matches nothing and spins forever.
	while timer <= 0 and anim_state != anim.IDLE:
		iterate()

func turn_on_gun() -> void:
	# Always start from a known timer. A value left over from an interrupted
	# cycle used to delay the beam by up to shoot_timer seconds.
	timer = 0.0
	anim_state = anim.OPEN_FLARE

func turn_off_gun() -> void:
	if anim_state == anim.IDLE:
		return
	timer = 0.0
	anim_state = anim.CLOSE_FLARE

func turn_on_barrel() -> void:
	timer = 0.0
	anim_state = anim.IDLE
	hummer.volume_db = -80
	hitbox.ignore_hits = true
	barrel.visible = true
	flare.visible = false
	shooter.visible = false

func turn_on_flare() -> void:
	hummer.volume_db = -80
	hitbox.ignore_hits = true
	barrel.visible = false
	flare.visible = true
	shooter.visible = false

func turn_on_shooter() -> void:
	boomer.play()
	hummer.volume_db = 0.0
	hitbox.ignore_hits = false
	barrel.visible = false
	flare.visible = false
	shooter.visible = true
