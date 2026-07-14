extends Node2D

@export_enum("Crew Quarters", "Bio Research Sector") var region: int
@export var activeTimeSeconds = 1.5

@onready var BRS = $ActiveBRS
@onready var CQ = $ActiveCQ
@onready var idle = $IdleTexture
@onready var anim_states = [ $Active1, $Active2, $Active3, $Active4 ]

var _active_timer = 0
var _timer_passive = 0
var _start_pos : Vector2
var _timer = 0
var _anim_state = 0
var _is_on = false
var _map_image
var _has_been_interacted_with = false

func _ready() -> void:
	setIdle()
	if MetSys.register_storable_object(self, func(): _has_been_interacted_with = true):
		return
	
	if region == 0:
		CQ.enabled = true
		_map_image = CQ
	elif region == 1:
		BRS.enabled = true
		_map_image = BRS
	
	_start_pos = _map_image.global_position

func _process(delta: float) -> void:
	passiveAnim(delta)
	if _is_on:
		activeAnim(delta)

func passiveAnim(delta: float) -> void:
	if _has_been_interacted_with and not _is_on:
		return
	
	_timer_passive += delta
	var time = TAU * _timer_passive
	var alpha = sin(time)
	var height = sin(time/2)
	_map_image.modulate = Color(1, 1, 1, alpha * alpha / 2 + 0.5)
	_map_image.global_position.y = _start_pos.y + height

func activeAnim(delta: float) -> void:
	_active_timer -= delta
	if _active_timer <= 0:
		setIdle()
		return
	
	# Switch frames every 20th a second
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
	_active_timer = activeTimeSeconds

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

func _on_interaction_entered(body: Node2D) -> void: 
	if not body.is_in_group("player") or _has_been_interacted_with:
		return
	
	_has_been_interacted_with = true
	var regionName = "Crew Quarters" if region == 0 else "Biological Research Sector"
	MetSys.discover_cell_group( MetSys.get_group_by_name(regionName) )
	MetSys.store_object(self)
	activate()
