## The player: a manager for the components that actually do the work.
##
## This file owns only what all of them share -- the input snapshot for the frame,
## the movement state, which way the player faces, which collider is active, and the
## order the components run in. Everything else lives in a [PlayerComponent] under
## this node, found by type in [method _collect_components], so a feature can be
## worked on, switched off, or taken out without touching anything else.
##
## Adding a component: give it a script extending [PlayerComponent], drop it under
## the player, and add it to [method _collect_components] if the manager needs to
## address it by name. It will already be getting [method PlayerComponent.bind] and
## the three update hooks.
##
## The frame runs in this order, and the order matters:
## [br]1. inputs are read once, into [member move_input] and friends
## [br]2. the mantle gets first refusal, because a vault owns the whole body
## [br]3. the move state and the collider that goes with it are settled
## [br]4. components take their turn, jump before movement so a launch this frame is
##      in the velocity movement then works with
## [br]5. [method move_and_slide]
## [br]6. post-move hooks, which are the only place the results of the move are known
class_name Player
extends CharacterBody2D

#region Signals
signal pickup_collected(pickup: Pickup)
signal save_station_used()
signal death_start(anim_duration: float)
signal death_end()
## Emitted by whatever launched the player -- the floor jump or the wall jump -- so
## the other one knows the ground has been spent.
signal jumped()
## Emitted after the move state changes, with the state left behind.
signal move_state_changed(from: MoveState, to: MoveState)
#endregion

enum MoveState {
	Standing,
	Crouching,
	Jumping,
	Knockback,
}

@export_group("World")
## Size of one tile in world pixels. Components measure jumps and vaults in tiles.
@export var tile_size := 48.0
@export_flags_2d_physics var geometry_layers := 1

@export_group("Visuals")
## How far down the visuals are shifted while the shorter air collider is active.
## Should match JumpCollision's offset from WalkingCollision in the player scene, so
## the collider bottoms and the sprite's feet all stay at the same height.
@export var airVisualOffset := 21.0

@export_group("Environment")
## How far below the feet of the active collider the crumbling-floor probe reaches.
## Just deep enough to land inside the tile being stood on.
@export var crumbleProbeDepth := 8.0
## How long floor snapping stays off after the ground under the player has been set
## off. Long enough to clear the tile that gave way; see [method _update_floor_snap].
@export var crumbleSnapPause := 0.25

## Group every BreakAbles layer joins, so the player can find the ones in the room it
## is standing in without the room having to wire them up.
const BREAKABLE_GROUP := &"BreakAbles"

#region Node references
@onready var collision_manager: CollisionManager = $CollisionManager
@onready var jump_sfx: AudioStreamPlayer2D = $SFX/JumpSFX
@onready var hurt_sfx: AudioStreamPlayer2D = $SFX/HurtSFX
@onready var melee_swing_sfx: AudioStreamPlayer2D = $SFX/MeleeSwingSFX
@onready var shoot_sfx: AudioStreamPlayer2D = $SFX/ShootSFX
@onready var animator := $Animator
@onready var health := $HealthComponent
@onready var mantle := $Mantle
@onready var planar_movement := $PlanarMovement
@onready var floor_jump := $FloorJump
@onready var wall_jump := $WallJump
@onready var jetpack := $Jetpack
@onready var wrench := $WrenchAttack
@onready var shooting := $Shooting

var _components: Array[PlayerComponent] = []
#endregion

#region Shared state
var move_input := 0.0
var crouch_input := false
var jump_held := false
var shoot_held := false
var attack_held := false
var facing_right := true
var move_state: MoveState = MoveState.Standing
var previous_move_state: MoveState = MoveState.Standing
var visual_offset := 0.0
var knockback_timer := 0.0
var knockback_force := 0.0
var gravity_override := -1.0
var horizontal_lock := 0.0
## Seconds of floor snapping still to be given up after a crumble gave way underfoot.
var _crumble_snap_timer := 0.0
## Seconds the wall-as-floor release is still held; see [method _release_wall_floor].
var _wall_floor_release := 0.0
## Height at the end of the last move, so [method _release_wall_floor] can tell a body
## that is standing from one that is slowly losing its grip.
var _last_ground_y := 0.0
var _visual_offset_nodes: Array[Node2D] = []
var _visual_offset_bases: PackedVector2Array
var _dying := false
#endregion

func _ready() -> void:
	PlayerManager.player = self
	facing_right = true
	move_state = MoveState.Standing
	previous_move_state = MoveState.Standing

	_components.clear()
	for child in get_children():
		var component := child as PlayerComponent
		if component:
			_components.append(component)
	_components.sort_custom(_component_order)
	
	_cache_visual_offset_nodes()

	if health:
		health.knocked_back.connect(_on_knocked_back)
	jumped.connect(_on_jumped)
	for component in _components:
		component.bind(self)

	collision_manager.swap_active_collision(_collider_for_state(move_state))
	_align_visuals_to_collider(_collider_for_state(move_state))

func _component_order(a: PlayerComponent, b: PlayerComponent) -> bool:
	return _order_of(a) < _order_of(b)

func _order_of(component: PlayerComponent) -> int:
	if component is PlayerMantle: return 0
	if component is PlayerWallJump: return 1
	if component is PlayerFloorJump: return 2
	if component is PlayerJetpack: return 3
	if component is PlayerPlanarMovement: return 4
	if component is PlayerWrenchAttack: return 5
	if component is PlayerShooting: return 6
	if component is PlayerAnimator: return 8
	return 7

#region Frame
func _process(delta: float) -> void:
	_read_inputs()

	for component in _components:
		if component.component_enabled:
			component.frame_update(delta)

func _physics_process(delta: float) -> void:
	# A vault owns the whole body: no gravity, no steering, no attacks until it hands
	# control back. It still gets its own update so it can decide when that is.
	if mantle and mantle.is_active():
		return

	_update_move_state()

	for component in _components:
		if component.component_enabled:
			component.physics_update(delta)

	_apply_animation()
	_update_floor_snap(delta)

	move_and_slide()
	_release_wall_floor(delta)

	for component in _components:
		if component.component_enabled:
			component.post_move_update(delta)

	_handle_crumbling_floor()
	_refresh_cell_group_music()

func _read_inputs() -> void:
	if not can_act():
		return

	move_input = Input.get_axis("Left", "Right")
	crouch_input = Input.is_action_pressed("Crouch")
	jump_held = Input.is_action_pressed("Jump")
	shoot_held = Input.is_action_pressed("Shoot")
	attack_held = Input.is_action_pressed("Attack")

	if Input.is_action_just_pressed("Jump"):
		_on_jump_pressed()
	if Input.is_action_just_pressed("Attack") and wrench:
		wrench.on_attack_pressed()
	if Input.is_action_just_pressed("Shoot") and shooting:
		shooting.on_shoot_pressed()

## A press goes to the mantle first: at a ledge it is a vault, and only otherwise a
## jump. Both jump components hear about it either way, so their buffers stay in step.
func _on_jump_pressed() -> void:
	if mantle and mantle.try_mantle():
		return
	if floor_jump:
		floor_jump.on_jump_pressed()
	if wall_jump:
		wall_jump.on_jump_pressed()

## Whether the player is allowed to act on input at all.
func can_act() -> bool:
	return PlayerManager.canMove and not _dying and not (health and health.is_dead())
#endregion

#region Move state
func _update_move_state() -> void:
	previous_move_state = move_state
	move_state = _determine_move_state()
	if previous_move_state == move_state:
		return

	var collider := _collider_for_state(move_state)
	collision_manager.swap_active_collision(collider)
	_align_visuals_to_collider(collider)
	move_state_changed.emit(previous_move_state, move_state)
	_play_transition_action(previous_move_state, move_state)

func _play_transition_action(from: MoveState, to: MoveState) -> void:
	if animator == null:
		return
	if from == MoveState.Jumping and (to == MoveState.Standing or to == MoveState.Crouching):
		animator.request_action(&"land")
	elif to == MoveState.Crouching:
		animator.request_action(&"crouch_down")

func _on_jumped() -> void:
	if animator == null:
		return
	var pushed_off: bool = wall_jump != null and wall_jump.launched_recently()
	animator.request_action(&"wall_push" if pushed_off else &"jump_start")

func _determine_move_state() -> MoveState:
	var wanted := _wanted_move_state()
	if _needs_headroom(wanted) and not has_headroom():
		return MoveState.Crouching
	return wanted

func _wanted_move_state() -> MoveState:
	if knockback_timer > 0.0:
		return MoveState.Knockback
	if not is_grounded() and (floor_jump == null or not floor_jump.can_jump()):
		return MoveState.Jumping
	if crouch_input:
		return MoveState.Crouching
	return MoveState.Standing

func _needs_headroom(state: MoveState) -> bool:
	return _collider_for_state(state) == CollisionManager.State.WALK or (previous_move_state == MoveState.Crouching and state != MoveState.Crouching)

func enter_state(state: MoveState) -> void:
	previous_move_state = move_state
	move_state = state
	var collider := _collider_for_state(state)
	collision_manager.swap_active_collision(collider)
	_align_visuals_to_collider(collider)
	if previous_move_state != state:
		move_state_changed.emit(previous_move_state, state)

func _collider_for_state(state: MoveState) -> CollisionManager.State:
	match state:
		MoveState.Jumping:
			return CollisionManager.State.AIR
		MoveState.Crouching:
			return CollisionManager.State.CROUCH
		_:
			return CollisionManager.State.WALK

const WALL_FLOOR_RELEASE_SECONDS := 0.2

func _release_wall_floor(delta: float) -> void:
	# Sinking is the third part of the test, and it is what keeps the release rare.
	# Standing still against an ordinary wall also reports a floor with no floor
	# contact -- nothing moved, so nothing collided downwards -- and dropping the
	# setting there would give up the protection every time the player leant on a wall.
	# A body that is genuinely standing does not descend; one hanging on a wall does.
	var sinking := global_position.y - _last_ground_y > 0.001
	_last_ground_y = global_position.y

	if is_on_floor() and sinking and not _has_floor_contact():
		_wall_floor_release = WALL_FLOOR_RELEASE_SECONDS
	else:
		_wall_floor_release = maxf(_wall_floor_release - delta, 0.0)

	var wanted: bool = planar_movement.block_on_wall if planar_movement else true
	floor_block_on_wall = wanted and _wall_floor_release <= 0.0

## Whether anything the body actually touched this frame was a floor.
func _has_floor_contact() -> bool:
	for i in get_slide_collision_count():
		if _is_floor_normal(get_slide_collision(i).get_normal()):
			return true
	return false

func _is_floor_normal(normal: Vector2) -> bool:
	# A hair of slack, so a surface drawn exactly at the limit is not decided by
	# floating point.
	return absf(normal.angle_to(up_direction)) <= floor_max_angle + 0.01

func is_grounded() -> bool:
	if not is_on_floor():
		return false
	var normal := get_floor_normal()
	return normal.is_zero_approx() or _is_floor_normal(normal)

func has_headroom() -> bool:
	var shape_node := collision_manager.collider_for(CollisionManager.State.WALK)
	if shape_node == null or shape_node.shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = geometry_layers
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
#endregion

#region Animation
func _apply_animation() -> void:
	if animator == null:
		return
	animator.request_pose(_pose_for_state())

## The resting look for the state the player is in.
func _pose_for_state() -> StringName:
	match move_state:
		MoveState.Jumping:
			if jetpack and jetpack.is_thrusting():
				return &"jetpack"
			if wall_jump and wall_jump.is_wall_available():
				return &"wall_slide"
			return &"jump"
		MoveState.Crouching:
			return &"crawl" if _is_moving() else &"crouch"
		MoveState.Knockback:
			if not is_grounded():
				return &"jump"
			return &"run" if _is_moving() else &"idle"
		_:
			return &"run" if _is_moving() else &"idle"

func _is_moving() -> bool:
	if planar_movement:
		return planar_movement.is_walking()
	return not is_zero_approx(move_input)
#endregion

#region Collider-aligned visuals
func _cache_visual_offset_nodes() -> void:
	_visual_offset_nodes = []
	_visual_offset_bases = PackedVector2Array()
	for node in [get_node_or_null(^"Character"), get_node_or_null(^"HealthComponent/Hurtbox")]:
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		_visual_offset_nodes.append(node_2d)
		_visual_offset_bases.append(node_2d.position)

func _align_visuals_to_collider(state: CollisionManager.State) -> void:
	var offset := airVisualOffset if state == CollisionManager.State.AIR else 0.0
	if is_equal_approx(offset, visual_offset):
		return

	visual_offset = offset
	for i in _visual_offset_nodes.size():
		_visual_offset_nodes[i].position = _visual_offset_bases[i] + Vector2(0.0, offset)
#endregion

#region Cross-component plumbing
## The wrench and the gun share a cooldown, so one cannot be used to skip the other's.
func share_attack_cooldown(seconds: float) -> void:
	if shooting:
		shooting.block_for(seconds)

func share_shoot_cooldown(seconds: float) -> void:
	if wrench:
		wrench.block_for(seconds)

func _on_knocked_back(force: float, duration: float) -> void:
	knockback_force = force
	knockback_timer = duration
	if animator:
		animator.request_action(&"knockback")
#endregion

#region Damage, death and respawn
## Called by the health component once health reaches zero.
func on_death() -> void:
	if _dying:
		return
	_dying = true
	reset_all_inputs()
	if animator:
		animator.request_held_action(&"death")
		death_start.emit(animator.animation_length(&"death"))
	else:
		death_start.emit(0.0)

func respawn() -> void:
	_dying = false
	velocity = Vector2.ZERO
	gravity_override = -1.0
	horizontal_lock = 0.0
	knockback_timer = 0.0
	knockback_force = 0.0
	reset_all_inputs()
	enter_state(MoveState.Standing)

	for component in _components:
		component.on_respawn()
	if health:
		health.refresh_from_save()
	death_end.emit()

func collect(pickup: Pickup) -> bool:
	pickup_collected.emit(pickup)
	return true
#endregion

#region Ability toggles kept for the rest of the game to call
func enable_jetpack() -> void:
	if jetpack:
		jetpack.set_unlocked(true)

func disable_jetpack() -> void:
	if jetpack:
		jetpack.set_unlocked(false)

func enable_gun() -> void:
	if shooting:
		shooting.enable_gun()

func disable_gun() -> void:
	if shooting:
		shooting.disable_gun()

func set_gun(mode: StringName) -> void:
	if shooting:
		shooting.set_gun(mode)

## Holds the jetpack off while the player is somewhere it must not fire (a ladder),
## without touching whether they own one.
func set_jetpack_suppressed(suppressed: bool) -> void:
	if jetpack:
		jetpack.set_suppressed(suppressed)
#endregion

#region Inputs
func reset_all_inputs() -> void:
	move_input = 0.0
	crouch_input = false
	jump_held = false
	shoot_held = false
	attack_held = false
	if floor_jump:
		floor_jump.consume_jump_buffer()
#endregion

#region World interaction
## Crumbling breakable tiles have no hitbox to be caught by, so the player is what
## tells them they are being stood on. Only the single cell under the centre of the
## player counts, which is what keeps the edges of a crumbling floor forgiving:
## clipping a corner of one is not standing on it.
func _handle_crumbling_floor() -> void:
	if not is_grounded():
		return

	var layers := get_tree().get_nodes_in_group(BREAKABLE_GROUP)
	if layers.is_empty():
		return

	var bounds := collision_manager.get_bounds()
	var feet := maxf(bounds[0].y, bounds[1].y)
	var probe := Vector2(global_position.x, feet + crumbleProbeDepth)
	var foreground := PlayerGeometry.foreground(get_tree())
	var crumbling := false
	for layer in layers:
		if layer.step_on(probe, foreground):
			crumbling = true
	if crumbling:
		_crumble_snap_timer = crumbleSnapPause

func _update_floor_snap(delta: float) -> void:
	if _crumble_snap_timer <= 0.0:
		return
	_crumble_snap_timer -= delta
	if _crumble_snap_timer > 0.0:
		floor_snap_length = 0.0
	elif planar_movement:
		floor_snap_length = planar_movement.slope_snap_length

func _refresh_cell_group_music() -> void:
	var groups := MetSys.get_cell_groups(MetSys.get_current_coords())
	if groups.is_empty():
		return
	MusicManager.set_background_track(groups)

func get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func get_foreground() -> TileMapLayer:
	return PlayerGeometry.foreground(get_tree())
#endregion
