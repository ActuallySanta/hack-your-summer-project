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

## The first component of [param type] under this node, or null.
func get_component(type: Variant) -> PlayerComponent:
	for component in _components:
		if is_instance_of(component, type):
			return component
	return null

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
		mantle.physics_update(delta)
		return

	_update_move_state()

	for component in _components:
		if component.component_enabled:
			component.physics_update(delta)

	_apply_animation()
	_update_floor_snap(delta)

	move_and_slide()

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

## The state the player is in this frame, which is also the collider they wear.
##
## [b]Room to be in it.[/b] The walking collider is 90px tall against the air
## collider's 48 and the crouch box's 20, so a state is only available where its shape
## fits. Swapping a tall one in where it does not buries half of it in the ceiling, and
## the engine throws the player sideways getting it back out -- the "caught in the
## corner, then stood up" of a ledge under an overhang.
##
## Asking per collider rather than per situation is what closes that off for good. The
## first go at this asked "are they landing, or already crouched", which left standing
## itself as a way in: for [member PlayerFloorJump.coyote_time] after walking off a
## ledge the player counts as neither jumping nor on the floor, so they were briefly
## Standing in mid-air -- tall collider and all -- under the very overhang they had
## just crouched to get under.
func _determine_move_state() -> MoveState:
	var wanted := _wanted_move_state()
	if _needs_headroom(wanted) and not has_headroom():
		return MoveState.Crouching
	return wanted

## What the player would be if there were room for it.
func _wanted_move_state() -> MoveState:
	if knockback_timer > 0.0:
		return MoveState.Knockback
	if not is_on_floor() and (floor_jump == null or not floor_jump.can_jump()):
		return MoveState.Jumping
	if crouch_input:
		return MoveState.Crouching
	return MoveState.Standing

## Whether [param state] can only be entered somewhere the player could stand up.
##
## Two ways to need it. The state wears the walking collider -- standing, and being
## knocked about -- or the player is crouched and would be coming up out of it, where
## even the air collider has to fit: a crawl space is one tile high and so is that
## shape, which is exactly the fit that wedges.
func _needs_headroom(state: MoveState) -> bool:
	return _collider_for_state(state) == CollisionManager.State.WALK \
		or (previous_move_state == MoveState.Crouching and state != MoveState.Crouching)

## Puts the player into [param state] and swaps the collider to match, for the moments
## something else decides the state outright (coming out of a vault).
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

## Whether the standing collider would fit where the player is right now.
##
## Asked of the shape itself rather than of the tiles above the crouch box: a tile
## check counts a cell as blocking whether or not what is in it has a collider, and
## misses anything that is not a tile at all.
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
## Turns the frame's state into one request to the animator. This is the only place
## the resting pose is chosen, so there is one answer per frame rather than several
## components each having an opinion.
func _apply_animation() -> void:
	if animator == null:
		return
	# Requested every frame even while a one-shot is playing: the animator holds the
	# pose rather than playing it, so the right thing is already queued for the moment
	# the swing, the shot or the hit ends.
	animator.request_pose(_pose_for_state())

## The resting look for the state the player is in.
func _pose_for_state() -> StringName:
	match move_state:
		MoveState.Jumping:
			if jetpack and jetpack.is_thrusting():
				return &"jetpack"
			if wall_jump and wall_jump.is_wall_available():
				return &"wall_cling"
			return &"jump"
		MoveState.Crouching:
			return &"crawl" if _is_moving() else &"crouch"
		MoveState.Knockback:
			# Being knocked about outlasts the animation that goes with it: the hit
			# plays a 0.4s reaction, while the fallen cyborg's knockback holds the
			# player for a full second. This branch used to ask for nothing at all, on
			# the grounds that the reaction was already playing -- but a pose is not a
			# one-shot, and asking for one cannot restart it. All that did was leave
			# whatever pose was up when the hit landed to come back when the reaction
			# ended: falling onto an enemy left the player skidding along the floor in
			# the falling pose, and being hit while crouched left them crawling.
			if not is_on_floor():
				return &"jump"
			return &"run" if _is_moving() else &"idle"
		_:
			return &"run" if _is_moving() else &"idle"

## Whether the player is actually travelling. Held input alone is not enough: pushing
## into a wall is not walking, and playing the walk cycle there is what made the
## player look like they were jogging on the spot.
func _is_moving() -> bool:
	if planar_movement:
		return planar_movement.is_walking()
	return not is_zero_approx(move_input)
#endregion

#region Collider-aligned visuals
## The air collider is shorter than the walking one and is pushed down in the editor
## so every collider shares the same bottom edge, which keeps the body origin (and so
## the camera) at one height through a jump and landing. The visuals have to make the
## same trip or the sprite hops up when the jump starts and drops when it ends.
func _cache_visual_offset_nodes() -> void:
	_visual_offset_nodes = []
	_visual_offset_bases = PackedVector2Array()
	for node in [get_node_or_null(^"Character"), get_node_or_null(^"JetpackAsset"), get_node_or_null(^"HealthComponent/Hurtbox")]:
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
	if not is_on_floor():
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

## Floor snapping is given up while the ground under the player is on its way out.
##
## Snapping is there for slopes: without it, walking down one is a series of little
## hops (see [member PlayerPlanarMovement.slope_snap_length]). But it applies to any
## floor lost from under the body, and it works by [i]moving the body[/i] rather than
## by letting it fall. So when a crumbling tile gave way the player was pulled the
## snap length straight down onto whatever was beneath it -- at no speed at all, still
## reading as on the floor. On a stack of crumbles that repeats every frame: 32px a
## frame, which is faster than terminal velocity, with none of it coming from falling.
## That is the teleport, and the sudden speed, in one mechanism.
##
## Giving the snap up for a moment turns it back into stepping off a ledge. Slopes are
## untouched: nothing crumbles under the player there, so the timer never starts.
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
