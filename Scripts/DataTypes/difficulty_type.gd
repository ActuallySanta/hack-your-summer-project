## Data for different difficulty types
##
## Once one of the factors for difficulty is set, it shouldn't be allowed to change again
## Access each value you want directly
class_name DifficultyType extends RefCounted

var _has_been_set : bool = false:
	set(new_value):
		if _has_been_set: return
		_has_been_set = new_value

var can_save : bool:
	set(val):
		if _has_been_set: return
		can_save = val
		
var aggressive_mode : bool:
	set(val):
		if _has_been_set: return
		aggressive_mode = val

var player_invincibility_factor : float:
	set(val): 
		if _has_been_set: return
		player_invincibility_factor = val

var enemy_stun_factor : float:
	set(val):
		if _has_been_set: return
		enemy_stun_factor = val

var damage_factor : float:
	set(val):
		if _has_been_set: return
		damage_factor = val
		
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
