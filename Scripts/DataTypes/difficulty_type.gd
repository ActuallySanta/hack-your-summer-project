## Data for different difficulty types
##
## Once one of the factors for difficulty is set, it shouldn't be allowed to change again
## Access each value you want directly
class_name DifficultyType extends RefCounted

## This is used to not allow changes to difficulty stats since there is no readonly in GDscript
var _has_been_set : bool = false:
	set(new_value):
		if _has_been_set: return
		_has_been_set = new_value

## The most insane factor, if you want out, you restart or tab out
var can_save : bool:
	set(val):
		if _has_been_set: return
		can_save = val

## Toggle for more difficult behavior
var aggressive_mode : bool:
	set(val):
		if _has_been_set: return
		aggressive_mode = val

## How long the player has invinicibility frames
var player_invincibility_factor : float:
	set(val): 
		if _has_been_set: return
		player_invincibility_factor = val

## How long enemies are in their respective "stun" state
var enemy_stun_factor : float:
	set(val):
		if _has_been_set: return
		enemy_stun_factor = val

## Non player dmg = this * base
var damage_factor : float:
	set(val):
		if _has_been_set: return
		damage_factor = val

## Player dmg = this * base
var player_damage_factor : float:
	set(val):
		if _has_been_set: return
		player_damage_factor = val

func _init(can_save_value: bool, aggressive_mode_value: bool, damage_factor_value: float, player_damage_factor_value: float, enemy_stun_time_value: float, player_invincibility_factor_value: float) -> void:
	can_save = can_save_value
	aggressive_mode = aggressive_mode_value
	damage_factor = damage_factor_value 
	player_damage_factor = player_damage_factor_value
	enemy_stun_factor = enemy_stun_time_value
	player_invincibility_factor = player_invincibility_factor_value
	_has_been_set = true
