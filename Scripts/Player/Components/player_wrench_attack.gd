## The wrench swing on the attack button.
##
## [b]Carrying one.[/b] The player starts with no wrench and is handed one in the
## tutorial, so the button does nothing until [method enable_wrench] says otherwise --
## the same gate [PlayerShooting] puts on the gun, and driven from the same place:
## [SaveManager] hands both out when a save is loaded, and the pickup announces itself
## through [signal Player.pickup_collected] when one is taken mid-run. Which wrench is
## being swung is [method set_wrench], mirroring the gun's modes.
##
## [b]Damage.[/b] The wrench is meant to get stronger later, so its damage is
## [member base_damage] plus a bonus that lives in the save file rather than in this
## node. [method set_damage_bonus] is the only way in, so an upgrade picked up in one
## room and a reload three rooms later cannot disagree about how hard the wrench hits.
## The bonus is what the Allen wrench should be paying out; [method wrench_mode] says
## which wrench is in hand if you would rather read the damage off that.
##
## [b]Swinging while crouched.[/b] The swing no longer stands the player up. It keeps
## the crouch, drops the hitbox to crouch height, and asks the animator for
## [code]swing_crouch[/code] -- which falls back to holding the crouch pose until that
## animation is drawn, rather than to the standing swing that used to poke the sprite
## through the ceiling.
class_name PlayerWrenchAttack
extends PlayerComponent

signal attacked(crouched: bool)

## Wrenches the player can carry.
const WRENCH_MODES: Array[StringName] = [&"basic", &"allen"]

@export_group("Swing")
@export var swing_scene: PackedScene
@export var cooldown := 0.45
@export var buffer_time := 0.15
## How far in front of the player the swing is placed while standing.
@export var swing_offset := 80.0
## Where the swing sits while crouched. Down at crouch height, so a crouched swing
## reaches what the player can actually see.
@export var crouch_swing_offset := Vector2(80.0, 30.0)

@export_group("Damage")
## Damage before any upgrade. The upgrade itself is saved; this is the floor.
@export var base_damage := 1
## Saved key the bonus is kept under, so a new upgrade only has to add to it.
@export var save_key := "wrench_damage_bonus"

@export_group("Animation")
@export var stand_animation: StringName = &"swing_standing"
@export var crouch_animation: StringName = &"swing_crouch"
@export var air_animation: StringName = &"swing_jump"

var _has_wrench := false
var _mode: StringName = &"basic"
## Extra damage from upgrades. Mirrored from the save; never written to directly.
var _damage_bonus := 0
var _cooldown_timer := 0.0
var _buffer_timer := 0.0

func _bind() -> void:
	refresh_from_save()

#region Wrench state
func has_wrench() -> bool:
	return _has_wrench

func enable_wrench() -> void:
	_has_wrench = true

func disable_wrench() -> void:
	_has_wrench = false

func set_wrench(mode: StringName) -> void:
	if not mode in WRENCH_MODES:
		printerr("PlayerWrenchAttack: \"%s\" is not a wrench mode." % mode)
		return
	_mode = mode

func wrench_mode() -> StringName:
	return _mode
#endregion

#region Damage
func damage() -> int:
	return base_damage + _damage_bonus

func set_damage_bonus(bonus: int) -> void:
	_damage_bonus = maxi(bonus, 0)
	SaveManager.set_value(save_key, _damage_bonus)

func add_damage_bonus(amount: int) -> void:
	set_damage_bonus(_damage_bonus + amount)

func refresh_from_save() -> void:
	_damage_bonus = int(SaveManager.get_value(save_key, 0))
#endregion

func on_attack_pressed() -> void:
	if not _has_wrench:
		return
	_buffer_timer = buffer_time

func physics_update(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _buffer_timer <= 0.0:
		return
	if _cooldown_timer <= 0.0:
		attack()
	else:
		_buffer_timer -= delta

func attack() -> void:
	if swing_scene == null or not _has_wrench:
		return

	var crouched := player.move_state == Player.MoveState.Crouching
	var swing := swing_scene.instantiate() as PlayerMeleeSwing
	swing.pending_damage = damage()

	var offset := crouch_swing_offset if crouched else Vector2(swing_offset, 0.0)
	if not player.facing_right:
		offset.x *= -1.0
		swing.scale.x = -1.0
	swing.position = offset
	player.add_child(swing)

	_cooldown_timer = cooldown
	_buffer_timer = 0.0
	player.shooting.block_for(cooldown)
	player.melee_swing_sfx.play()

	var animation := crouch_animation if crouched \
		else air_animation if player.move_state == Player.MoveState.Jumping \
		else stand_animation
	player.animator.request_action(animation)
	attacked.emit(crouched)

func on_respawn() -> void:
	_cooldown_timer = 0.0
	_buffer_timer = 0.0
	refresh_from_save()

## Puts the swing on cooldown from outside, so firing the gun still blocks a swing.
func block_for(seconds: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer, seconds)
