extends Node2D

@export_enum("Crew Quarters", "Bio Research Sector") var region: int

@onready var BRS = $ActiveBRS
@onready var CQ = $ActiveCQ
@onready var idle = $IdleTexture
@onready var anim_states = [ $Active1, $Active2, $Active3, $Active4 ]

var _timer_passive = 0
var _start_pos : Vector2

var _timer = 0
var _anim_state = 0
var _is_on = false
var _map_image

func _ready() -> void:
	setIdle()
	
	if region == 0:
		CQ.enabled = true
		_map_image = CQ
	elif region == 1:
		BRS.enabled = true
		_map_image = BRS
	
	_start_pos = _map_image.global_position

func _process(delta: float) -> void:
	# handle passive animation logic
	_timer_passive += delta
	var time = TAU * _timer_passive
	var alpha = sin(time)
	var height = sin(time/2)
	_map_image.modulate = Color(1, 1, 1, alpha * alpha / 2 + 0.5)
	_map_image.global_position.y = _start_pos.y + height
	
	# handle Activated animation logic
	if not _is_on:
		return
	
	_timer += delta * 20
	while _timer >= 1:
		_timer -= 1
		_anim_state += 1
	
	toggleAnimState( _anim_state % 4 )

func setIdle() -> void:
	_is_on = false
	idle.enabled = true
	BRS.enabled = false
	CQ.enabled = false
	for state in anim_states:
		state.enabled = false

func activate() -> void:
	_is_on = true
	idle.enabled = false;

func toggleAnimState(num: int):
	match num:
		0:
			anim_states[ 3 ].enabled = false
			anim_states[ 0 ].enabled = true
		1:
			anim_states[ 0 ].enabled = false
			anim_states[ 1 ].enabled = true
		2:
			anim_states[ 1 ].enabled = false
			anim_states[ 2 ].enabled = true
		3:
			anim_states[ 2 ].enabled = false
			anim_states[ 3 ].enabled = true
