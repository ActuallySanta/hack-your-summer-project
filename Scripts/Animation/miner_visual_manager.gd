extends Node2D

@export var panel_fall_speed : float = 7

@onready var body = $Flasher/Body
@onready var eye = $Flasher/Eye
@onready var panel = $Panel

var _heavy_damage : bool
var _do_falling : bool
var _panel_velocity : float = 0
var _panel_init_pos : Vector2

func _ready() -> void:
	_panel_init_pos = position

func _process(delta: float) -> void:
	if _do_falling:
		_panel_velocity += panel_fall_speed * delta
		panel.position += Vector2.DOWN * _panel_velocity

func _animate_panel() -> void:
	panel.visible = true
	panel.play("PanelFall")
	await panel.animation_finished
	_do_falling = true

func switch_to_healed() -> void:
	_heavy_damage = false
	panel.visible = false
	body.frame = 0
	_panel_velocity = 0
	_do_falling = false
	panel.position = _panel_init_pos

func switch_to_damaged() -> void:
	if _heavy_damage: return
	_heavy_damage = true
	_animate_panel()
	body.frame = 1

func move_eye(target_global_position: Vector2) -> void:
	var target_position : Vector2 = ((target_global_position - eye.offset) - eye.global_position)
	target_position = target_position.normalized()
	eye.position = target_position
	
