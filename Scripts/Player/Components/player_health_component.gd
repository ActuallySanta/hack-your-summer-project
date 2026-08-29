## The player's health, hit reaction, invulnerability and death.
##
## Inherits [HealthComponent] like the drone's does, so hits arrive through the same
## [Hurtbox] wiring every other body in the game uses.
##
## [b]Why maximum health is not a counter.[/b] It used to be: picking up an extender
## added one to a variable on the player. Nothing saved it, and nothing tied it to
## whether the pickup had actually been recorded as collected, so the two could
## disagree in three different ways -- the upgrade was lost on quitting, it survived a
## death that reverted the pickup, and a pickup that respawned because the run had not
## been saved could be taken again for another point, over and over.
##
## The count is now derived, not accumulated: the save holds the [i]set of extenders
## collected[/i], and maximum health is the base plus the size of that set. Collecting
## the same extender twice adds nothing because the set already has it, and reloading
## puts health and pickups back to the same moment because they are the same fact.
class_name PlayerHealthComponent
extends HealthComponent

## Emitted on a hit that lands, with the knockback it carries.
signal knocked_back(force: float, duration: float)
## Emitted whenever current or maximum health changes, before the global signal.
signal health_updated(current: int, maximum: int)

@export_group("Health")
## Maximum health with no extenders collected.
@export var base_max_health := 3

@export_group("Invulnerability")
## How long the player cannot be hit again after a hit lands.
@export var invulnerable_seconds := 1.0
## How fast the sprite blinks while invulnerable.
@export var blink_interval := 0.15

@export_group("Hurtbox pose")
## The hurtbox capsule's shape while upright, and while crawling.
##
## These used to be animation tracks. The [AnimationTree] blended any track the
## current animation did not drive back to its default, so the crouch pose came off
## by itself; a plain [AnimationPlayer] leaves whatever was last written in place, so
## the crouch hurtbox would have stuck around after standing up. They belong to the
## stance rather than to the animation anyway, so they are driven from the state
## change here and there is one owner of them again.
@export var stand_position := Vector2.ZERO
@export var stand_rotation_degrees := 0.0
@export var stand_height := 90.0
@export var crouch_position := Vector2(0.0, 21.0)
@export var crouch_rotation_degrees := 90.0
@export var crouch_height := 60.0

var _invuln_timer := 0.0
var _blink_timer := 0.0
var _dead := false
## The hurtbox's shape node, and a copy of its shape so resizing it cannot reach the
## scene's own resource (which every instance of the player scene would share).
var _hurt_shape: CollisionShape2D

func _ready() -> void:
	# Base _ready() connects the hurtbox and seeds health from start_health; the real
	# maximum is only knowable once the save is loaded, which refresh_from_save does.
	max_health = base_max_health
	start_health = base_max_health
	super()
	GlobalSignals.health_extended_by_one.connect(_on_extender_collected)

	_hurt_shape = hurtbox.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if _hurt_shape and _hurt_shape.shape:
		_hurt_shape.shape = _hurt_shape.shape.duplicate()
	var player := _player()
	if player:
		player.move_state_changed.connect(_on_move_state_changed)
	_apply_hurtbox_pose(false, false)

func _on_move_state_changed(_from: Player.MoveState, to: Player.MoveState) -> void:
	_apply_hurtbox_pose(to == Player.MoveState.Crouching, to == Player.MoveState.Jumping)

func _apply_hurtbox_pose(crouched: bool, jumping: bool) -> void:
	if _hurt_shape == null:
		return
	_hurt_shape.position = crouch_position if crouched else stand_position
	_hurt_shape.rotation_degrees = crouch_rotation_degrees if crouched else stand_rotation_degrees
	var capsule := _hurt_shape.shape as CapsuleShape2D
	if capsule:
		capsule.height = crouch_height if crouched or jumping else stand_height

func _player() -> Player:
	return get_parent() as Player

#region Save-derived maximum
## Re-reads the extenders collected and puts the player on full health.
##
## Called on every spawn -- new game, load, checkpoint respawn -- so the health bar
## always reflects the save that is actually loaded rather than whatever the previous
## run happened to leave behind.
func refresh_from_save() -> void:
	_dead = false
	_invuln_timer = 0.0
	_blink_timer = 0.0
	ignore_effects = false
	hurtbox.process_mode = Node.PROCESS_MODE_INHERIT
	max_health = base_max_health + GameManager.get_health_upgrade_count()
	max_out()
	_announce()

## An extender was collected for the first time. Both the ceiling and the current
## health go up, so the new point is usable straight away.
func _on_extender_collected() -> void:
	max_health = base_max_health + GameManager.get_health_upgrade_count()
	max_out()
	_announce()

func maximum_health() -> int:
	return max_health
#endregion

#region Hits
func _on_hit(_hurt_box: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	if _invuln_timer > 0.0 or _dead or ignore_effects:
		return

	take_damage(hit_info.damage)
	_announce()
	on_hit_event.emit()

	var player := _player()
	if player:
		player.hurt_sfx.play()
	if hit_info.knockback_duration > 0.0:
		knocked_back.emit(hit_info.knockback_strength / hit_info.knockback_duration, hit_info.knockback_duration)

	if _dead:
		return
	_invuln_timer = invulnerable_seconds
	_blink_timer = blink_interval
	# Taken out of the physics space rather than merely ignored, so overlapping
	# hitboxes do not queue up hits to land the moment the frames run out.
	hurtbox.process_mode = Node.PROCESS_MODE_DISABLED

func _on_death() -> void:
	if _dead:
		return
	_dead = true
	_invuln_timer = 0.0
	hurtbox.process_mode = Node.PROCESS_MODE_DISABLED
	on_death_event.emit()
	var player := _player()
	if player:
		player.on_death()

func is_dead() -> bool:
	return _dead

func is_invulnerable() -> bool:
	return _invuln_timer > 0.0
#endregion

func _process(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return

	_invuln_timer -= delta
	_blink_timer -= delta
	if _blink_timer < 0.0:
		_blink_timer += blink_interval

	var player := _player()
	if player and is_instance_valid(player.animator):
		player.animator.set_body_hidden_for_blink(_blink_timer > blink_interval * 0.5)

	if _invuln_timer <= 0.0:
		hurtbox.process_mode = Node.PROCESS_MODE_INHERIT
		if player and is_instance_valid(player.animator):
			player.animator.set_body_hidden_for_blink(false)

func _announce() -> void:
	health_updated.emit(int(current_health()), max_health)
	GlobalSignals.health_changed.emit(int(current_health()), max_health)
