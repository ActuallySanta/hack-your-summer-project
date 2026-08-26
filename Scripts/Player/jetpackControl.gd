## The jetpack the player wears: a sprite and two tuning numbers, nothing more.
##
## It used to read the input and drive the player itself, which is why turning on the
## jetpack also meant losing the ability to mantle. The thrust now lives in
## [PlayerJetpack], and this holds the values the designer tunes in the scene and the
## two textures.
class_name JetpackAsset
extends Sprite2D

const IDLE := preload("res://Sprites/Jetpack/jetpack_isOn_0.png")
const ACTIVE := preload("res://Sprites/Jetpack/jetpack_isOn_1.png")

## Upward acceleration at a standstill, before drag. Read by [PlayerJetpack].
@export var net_acceleration: float = 1800.0
## Speed the thrust fades out at. Read by [PlayerJetpack].
@export var max_speed: float = 800.0

func _ready() -> void:
	texture = IDLE

## Switches between the lit and unlit textures.
func set_lit(lit: bool) -> void:
	texture = ACTIVE if lit else IDLE
