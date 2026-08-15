extends Node2D

@export_enum("DB", "CQ", "BS", "RS", "OP", "IL") var what_to_keep : Array[ String ]

@onready var animator = $AnimationPlayer
@onready var BRS = $ActiveBRS
@onready var CQ = $ActiveCQ
@onready var idle = $IdleTexture
@onready var _map_image = $Hider/MapDisplay

var _timer_passive = 0
var _start_pos : Vector2
var _is_on = false
var _has_been_interacted_with = false

func _ready() -> void:
	if MetSys.register_storable_object(self, turn_off):
		return
	
	for i in what_to_keep:
		_map_image.show_sector( i )
	
	_start_pos = _map_image.global_position

func _process(delta: float) -> void:
	passiveAnim(delta)

func passiveAnim(delta: float) -> void:
	if _has_been_interacted_with and not _is_on:
		return
	
	_timer_passive += delta
	var time = TAU * _timer_passive
	var alpha = sin(time/10)
	var height = sin(time * 0.75)
	_map_image.modulate = Color(1, 1, 1, alpha * alpha / 2 + 0.5)
	_map_image.global_position.y = _start_pos.y + height
	_map_image.fade_fill(time)

func _on_interaction_entered(body: Node2D) -> void: 
	if not body.is_in_group("player") or _has_been_interacted_with:
		return
	
	_has_been_interacted_with = true
	var regionName : String
	for entry in what_to_keep:
		match entry:
			"DB":
				regionName = "Docking Bay"
			"CQ":
				regionName = "Crew Quarters"
			"BS":
				regionName = "BRS"
			"RS":
				regionName = "Maintainence"
			"OP":
				regionName = "Operations"
			"IL":
				regionName = "Internals"
		
		MetSys.discover_cell_group( MetSys.get_group_by_name(regionName) )
	MetSys.store_object(self)
	animator.play("Active")

func turn_off() -> void:
	_has_been_interacted_with = true
	animator.play("Off")
