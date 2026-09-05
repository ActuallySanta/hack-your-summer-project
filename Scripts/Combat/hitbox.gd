class_name Hitbox extends Area2D

## Hitbox detects Hurtbox objects and deals damage (and possibly knockback) to them.
##
## Hurtbox is an Area2D and needs a collision shape to be able to detect Hitboxes.[br]
## IT IS INTENTIONAL THAT THE BASE HITBOX SCENE HAS NO COLLISION SHAPE.[br]
## YOU ARE SUPPOSED TO ADD IT YOURSELF IN THE SCENE THAT YOU ADD THE HITBOX IN.[br]
## It is recommended to adjust the collision layer masks based on the intended
## targets of the hurtbox (CollisionObject2D -> Collison -> Mask).[br]
## THE BASE HITBOX SCENE SETS monitorable = false.[br]
## An Area2D with monitorable off is never paired against *static* bodies, so a
## Hitbox that needs to react to level geometry (StaticBody2D, TileMapLayer) must
## turn monitorable back on in its own scene, or environment_hit will never fire.[br]
## [br]
## Hitbox does not apply the damage or knockback, it simply communicates those values.
## The object that the Hitbox is attached to is what processes the hit.

signal on_hit(hitbox: Hitbox, target: Hurtbox)
signal environment_hit(target: Node2D)

@export var damage: int = 1
@export var knockback_strength: float = 150
@export var knockback_duration: float = 0.01

## Seconds before the same target can be hit again by this hitbox.
##
## 0 keeps the original rule: one hit per target, ever, until [method reset] is
## called. That is right for a hitbox that only exists for one swing, but wrong for
## one that stays in the world -- a boss's body, a hazard -- which under that rule
## can only ever damage the player once for the whole fight. Give those a value.
@export var hit_cooldown_seconds : float = 4

var ignore_hits : bool
## Targets already hit and not yet re-armed. Kept as an array because callers read it.
var previous_hits : Array[Hurtbox]
## When each of those was last hit, by instance id so a freed target cannot be held.
var _hit_at : Dictionary[int, float]
## Game time this hitbox has been alive for, used to date the entries above.
var _clock : float = 0.0

func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	self.area_exited.connect(_on_area_exited)
	self.body_entered.connect(_on_body_entered)
	previous_hits = []
	_hit_at = {}

func reset() -> void:
	previous_hits = []
	_hit_at = {}

func _on_area_entered(area: Area2D) -> void:
	if ignore_hits:
		return
	var hurtbox := area as Hurtbox
	if not hurtbox:
		return
	if not _can_hit(hurtbox):
		return
	if not previous_hits.has(hurtbox):
		previous_hits.append(hurtbox)
	_hit_at[hurtbox.get_instance_id()] = _now()
	on_hit.emit(self, hurtbox)
	var hit_info := HitInfo.new(damage, knockback_strength, knockback_duration)
	hurtbox.register_hit(hit_info, self)

## Leaving and coming back re-arms, whatever the cooldown says. Without this a target
## that walks out of a lasting hitbox and straight back in is never hit again.
func _on_area_exited(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if not hurtbox:
		return
	previous_hits.erase(hurtbox)
	_hit_at.erase(hurtbox.get_instance_id())

func _can_hit(hurtbox: Hurtbox) -> bool:
	if not previous_hits.has(hurtbox):
		return true
	if hit_cooldown_seconds <= 0.0:
		return false
	return _now() - _hit_at.get(hurtbox.get_instance_id(), 0.0) >= hit_cooldown_seconds

func _now() -> float:
	return _clock

## A target sitting inside a lasting hitbox produces no new area_entered, so the
## re-arm has to be looked for rather than waited for. Only runs when a cooldown is
## actually set, so hitboxes on the original one-shot rule cost nothing.
func _physics_process(delta: float) -> void:
	# Game time rather than wall clock, so a cooldown is not spent while the game is
	# paused and follows Engine.time_scale during a slow-motion moment.
	_clock += delta
	if ignore_hits or hit_cooldown_seconds <= 0.0 or previous_hits.is_empty():
		return
	for hurtbox in get_overlapping_areas():
		var target := hurtbox as Hurtbox
		if target and _can_hit(target):
			_hit_at[target.get_instance_id()] = _now()
			on_hit.emit(self, target)
			target.register_hit(HitInfo.new(damage, knockback_strength, knockback_duration), self)

## Layers that count as environment: level geometry (1) and BreakableBlocks (6).
const ENVIRONMENT_LAYERS := 1 << 0 | 1 << 5

func _on_body_entered(body: Node2D) -> void:
	if ignore_hits:
		return
	if body is TileMapLayer:
		environment_hit.emit(body)
		return
	var physics_body := body as PhysicsBody2D
	if physics_body and physics_body.collision_layer & ENVIRONMENT_LAYERS:
		environment_hit.emit(body)
