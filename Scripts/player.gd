class_name Player
extends CharacterBody2D

# Signals
signal pickup_collected(pickup : Pickup)
signal save_station_used()
signal death_start(anim_duration: float)
signal death_end()

# Exports
@export_group("Movement")
@export var moveSpeed := 500.0
@export var crouchSpeedMult := 0.5
@export var climbingSpeed := 100
@export var jumpForce := 600.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2
@export var wallJumpBufferTime := 0.2

@export_group("Combat")
@export var baseHealth := 5
@export var attackCooldown := 0.45
@export var attackBufferTime := 0.15
@export var swingOffset := 100.0
@export var swingScene : PackedScene
@export var shootCooldown := 0.6
@export var shootBufferTime := 0.15
@export var bulletOffset := 100.0
@export var bulletScene : PackedScene
@export var hitInvulnTime := 1.0
@export var invulnBlinkInterval := 0.15
@export var knockbackDI := 300.0
@export var canClimb : bool = false

# Enums
enum MoveState{
	Standing,
	Crouching,
	Climbing,
	Jumping,
	Knockback,
}

# Onreadys
@onready var animator: AnimationTree = $AnimationTree
@onready var animPlayback: AnimationNodeStateMachinePlayback = animator.get("parameters/playback")
@onready var jetpack: Sprite2D = $JetpackAsset
@onready var sprite : Sprite2D = $Character
@onready var collisionManager: Node = $CollisionManager

# Consts
const IDLESTATEPARAM := "parameters/StandardMovement/Idle/MoveState/transition_request"
const MOVESTATEPARAM := "parameters/StandardMovement/Move/MoveState/transition_request"
const FIRESTATEPARAM := "parameters/RangedFire/MoveState/transition_request"
const TILE_SIZE := 48
# Input
var _moveInput : float
var _vertMoveInput :float
var _crouchInput : bool
var _climbInput : bool
# Direction
var _facingRight : bool
# Jumping and air
var _jumpBufferTimer : float
var _coyoteTimer : float
var _wall_jump_speed_bonus : float
var _wall_jump_dir : float
var _wall_jump_buffer : float
# Health
var _currentHealth : int
# Attack
var _attackCooldownTimer : float
var _attackBufferTimer : float
# Shooting
var _shootCooldownTimer : float
var _shootBufferTimer : float
# Knockback
var _knockbackTimer : float
var _knockbackForce : float
# Invinciblity frames
var _invulnTimer : float
var _invulnBlinkTimer : float
var _deathRespawnTimer : float
# Mantling and Vaulting
var _is_vaulting : bool
# Camera offset
var _camera_offset : Vector2
var _need_to_move_camera : bool
# Camera animation
var _camera_anim_pos : Vector2
var _camera_anim_time : float
var _camera_anim_elapsed_time : float
# Player MoveState
var playerMoveState: MoveState
var previousMoveState: MoveState
#Animation
var anim_moving : bool
var anim_jumping : bool
var anim_hurt : bool
var anim_death : bool
var anim_swing : bool
var anim_fire : bool
# Map and MetSys
var previous_cell_Group := "None"


func _ready() -> void:
	PlayerManager.player = self
	_facingRight = true
	_currentHealth = baseHealth
	jetpack.jetpack_updated.connect(do_jetpack_logic)
	disable_jetpack()
	playerMoveState = MoveState.Standing

func _move_player_pos(pos: Vector2) -> void:
	position = pos

func jump() -> void:
	_jumpBufferTimer = 0
	_coyoteTimer = 0
	if try_mantle():
		return
	
	velocity.y = -jumpForce

func wall_jump() -> void:
	_jumpBufferTimer = 0
	_coyoteTimer = 0
	_wall_jump_buffer = 0
	
	_wall_jump_speed_bonus = 600
	_wall_jump_dir = _moveInput
	velocity.y = -800

func validate_wall_jump() -> bool:
	if not is_on_wall_only():
		return false

	var foreground = get_foreground()
	var blocks = [
		get_map_position(foreground, Vector2i(-_moveInput, -1)),
		get_map_position(foreground, Vector2i(-_moveInput, 0)),
		#get_map_position(foreground, Vector2i(-_moveInput, 1))
	]
	
	for block in blocks:
		if not is_tile_air(foreground, block):
			_wall_jump_buffer = wallJumpBufferTime
			return true
	return false

func attack() -> void:
	var newAttack := swingScene.instantiate() as PlayerMeleeSwing
	var swingX := swingOffset
	if !_facingRight:
		swingX *= -1
		newAttack.scale.x = -1
	newAttack.position = Vector2(swingX, 0)
	add_child(newAttack)
	_attackCooldownTimer = attackCooldown
	_shootCooldownTimer = attackCooldown
	_attackBufferTimer = 0
	anim_swing = true

func shoot() -> void:
	var newBullet := bulletScene.instantiate() as PlayerBullet
	var bulletX := bulletOffset
	if !_facingRight:
		bulletX *= -1
		newBullet.scale.x = -1
	newBullet.position = position + Vector2(bulletX, 0)
	newBullet.direction = Vector2.RIGHT if _facingRight else Vector2.LEFT
	get_tree().root.add_child(newBullet)
	_shootCooldownTimer = shootCooldown
	_attackCooldownTimer = shootCooldown
	_shootBufferTimer = 0
	anim_fire = true

#region Handlers
func handle_vertical_speed() -> void:
	if velocity.y < -1000:
		velocity.y = -1000
	elif velocity.y > 1500:
		velocity.y = 1500

func handle_jump_and_gravity(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		if(playerMoveState != MoveState.Climbing):
			velocity += get_gravity() * delta
		_coyoteTimer -= delta
	else:
		_coyoteTimer = coyoteTime
	
	# Handle jump.
	if _wall_jump_speed_bonus > 0:
		_wall_jump_speed_bonus -= 50
	
	
	if _jumpBufferTimer <= 0:
		return
	
	if not (is_on_floor() or _coyoteTimer > 0) and _wall_jump_buffer > 0:
		wall_jump()
	
	if (is_on_floor() or _coyoteTimer > 0) and playerMoveState != MoveState.Climbing:
		jump()
	else:
		_jumpBufferTimer -= delta

func handle_wall_jumping(delta: float) -> void:
	if not validate_wall_jump():
		_wall_jump_buffer -= delta

func handle_standard_movement(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	if _moveInput:
		velocity.x = _moveInput * moveSpeed
		if _wall_jump_speed_bonus > 0:
			velocity.x += _wall_jump_speed_bonus * _wall_jump_dir
		if(playerMoveState == MoveState.Crouching):
			velocity.x *= crouchSpeedMult
		_facingRight = _moveInput > 0
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed * 0.1)
	set_anim_move_state(playerMoveState, _moveInput != 0)

func handle_climbing_movement(_delta: float) -> void:
	velocity.x = 0
	velocity.y = _vertMoveInput * climbingSpeed
	set_anim_move_state(MoveState.Climbing, _vertMoveInput != 0)

func handle_knockback_movement(delta: float) -> void:
	velocity.x = _knockbackForce
	if _moveInput:
		velocity.x += _moveInput * knockbackDI
	_knockbackTimer -= delta
	set_anim_move_state(MoveState.Knockback, false)

func handle_inputs() -> void:
	if(!PlayerManager.canMove or _currentHealth <= 0): return
	
	_moveInput = Input.get_axis("Left", "Right")
	_vertMoveInput = Input.get_axis("Up","Down")
	_crouchInput = Input.is_action_pressed("Crouch")
	_climbInput = Input.is_action_pressed("Climb")	
	
	if Input.is_action_just_pressed("Jump"):
		set_jump_input()
	if Input.is_action_just_pressed("Attack"):
		set_attack_input()
	if Input.is_action_just_pressed("Shoot"):
		set_shoot_input()

func handle_invuln_blinking(delta: float) -> void:
	if _invulnTimer <= 0:
		_invulnBlinkTimer = 0
		sprite.show()
		return
	
	if _invulnBlinkTimer > invulnBlinkInterval/2:
		sprite.hide()
	else:
		sprite.show()
	_invulnBlinkTimer -= delta
	if _invulnBlinkTimer < 0:
		_invulnBlinkTimer += invulnBlinkInterval
#endregion

func determine_move_state() -> MoveState:
	if _knockbackTimer > 0:
		return MoveState.Knockback
	
	if is_on_wall() and _climbInput and canClimb:
		return MoveState.Climbing
	
	if !is_on_floor() and _coyoteTimer <= 0:
		return MoveState.Jumping
	
	if _crouchInput:
		return MoveState.Crouching
	
	return MoveState.Standing

func translate_state() -> CollisionManager.State:
	if playerMoveState == MoveState.Standing or playerMoveState == MoveState.Climbing or playerMoveState == MoveState.Knockback:
		return CollisionManager.State.WALK
	elif playerMoveState == MoveState.Jumping:
		return CollisionManager.State.AIR
	elif playerMoveState == MoveState.Crouching:
		return CollisionManager.State.CROUCH
	
	return CollisionManager.State.WALK

func on_cell_group_change(new_group: String) -> void:
	MusicManager.set_background_track(new_group)

func _physics_process(delta: float) -> void:
	if _is_vaulting:
		return
	
	previousMoveState = playerMoveState
	playerMoveState = determine_move_state()
	
	if previousMoveState != playerMoveState:
		collisionManager.swap_active_collision( translate_state() )
	
	handle_wall_jumping(delta)
	handle_jump_and_gravity(delta)
	
	if playerMoveState == MoveState.Knockback:
		handle_knockback_movement(delta)
	elif playerMoveState == MoveState.Climbing:
		handle_climbing_movement(delta)
	else:
		handle_standard_movement(delta)
	
	# Handle attack
	if _attackCooldownTimer > 0:
		_attackCooldownTimer -= delta
	if _attackBufferTimer > 0:
		if _attackCooldownTimer <= 0:
			attack()
		else:
			_attackBufferTimer -= delta
	# Handle shooting
	if _shootCooldownTimer > 0:
		_shootCooldownTimer -= delta
	if _shootBufferTimer > 0:
		if _shootCooldownTimer <= 0:
			shoot()
		else:
			_shootBufferTimer -= delta
	
	if _invulnTimer > 0:
		_invulnTimer -= delta
	move_and_slide()

	# 3. Flip the sprite visually based on which way we are running
	if _facingRight:
		sprite.flip_h = false  # Facing Right
	else:
		sprite.flip_h = true   # Facing Left

	var groups = MetSys.get_cell_groups( MetSys.get_current_coords() )
	if groups.size() == 0:
		return
	var group_id = groups[0]
	var group = MetSys.get_group_name( group_id )
	if group  != previous_cell_Group:
		on_cell_group_change(group)
		previous_cell_Group = group

func _process( _delta: float ) -> void:
	handle_inputs()
	handle_invuln_blinking( _delta )
	handle_vertical_speed()
	get_camera().global_position += _camera_offset
	if _need_to_move_camera:
		anim_camera_update( _delta )
	
	if animPlayback.get_current_node() == "RangedFire" or animPlayback.get_current_node() == "MeleeSwing":
		anim_fire = false
		anim_swing = false
	
#region Damage and respawn
func die() -> void:
	_invulnTimer = 0
	anim_death = true
	reset_all_inputs()
	_moveInput = 0
	$Hurtbox.process_mode = Node.PROCESS_MODE_DISABLED
	death_start.emit($AnimationPlayer.get_animation(&"death").length)

func respawn() -> void:
	$Hurtbox.process_mode = Node.PROCESS_MODE_INHERIT
	_currentHealth = baseHealth
	GlobalSignals.health_changed.emit(_currentHealth, baseHealth)
	anim_death = false

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	if _invulnTimer > 0 or _currentHealth <= 0:
		return
	_currentHealth -= hit_info.damage
	GlobalSignals.health_changed.emit(_currentHealth, baseHealth)
	_knockbackTimer = hit_info.knockback_duration
	_knockbackForce = hit_info.knockback_strength / _knockbackTimer
	_invulnTimer = hitInvulnTime
	_invulnBlinkTimer = invulnBlinkInterval
	anim_hurt = true
	if _currentHealth <= 0:
		die()
#endregion

func collect(pickup: Pickup) -> bool:
	print("Collect pickup " + pickup.get_type_as_str())
	pickup_collected.emit(pickup)
	return true

#region Jetpack
func do_jetpack_logic(net_accel: float, max_speed: float, delta: float):
	if _is_vaulting:
		return
	var drag_coef := -velocity.y/max_speed
	var total_accel := get_gravity().y + (net_accel * (1-drag_coef))
	velocity.y -= total_accel * delta

func disable_jetpack() -> void:
	jetpack.process_mode = Node.PROCESS_MODE_DISABLED

func enable_jetpack() -> void:
	jetpack.process_mode = Node.PROCESS_MODE_INHERIT
#endregion
	
#region Mantle
func try_mantle() -> bool:
	if not is_on_floor():
		return false
	
	var foreground = get_foreground()
	var mantle_block = get_map_position( foreground )
	mantle_block.x += -1 if sprite.flip_h else 1
	if is_tile_air(foreground, mantle_block):
		return false
	
	var air_check = Vector2i(mantle_block.x, mantle_block.y - 1)
	if not is_tile_air(foreground, air_check):
		return false
	
	mantle()
	return true

#TODO Replace both of these functions (As well as the tempClimber) with things in the animtree
func mantle() -> void:
	_is_vaulting = true
	$TempClimberSinceZachIsStupid.flip_h = sprite.flip_h
	$TempClimberSinceZachIsStupid.position.x = -15 if sprite.flip_h else 15
	$TempClimberSinceZachIsStupid.visible = true
	$Character.modulate = Color(1,1,1,0)
	$TempClimberSinceZachIsStupid.play("Small Climb")
	var camera_pos = Vector2(-TILE_SIZE,-TILE_SIZE) if sprite.flip_h else Vector2(TILE_SIZE, -TILE_SIZE)
	anim_camera_start(camera_pos.x, camera_pos.y, 0.25)

func _on_mantle_complete() -> void:
	_is_vaulting = false
	set_anim_move_state(MoveState.Crouching, false)
	$TempClimberSinceZachIsStupid.visible = false
	$Character.modulate = Color(1,1,1,1)
	position += Vector2(-TILE_SIZE,-TILE_SIZE) if sprite.flip_h else Vector2(TILE_SIZE, -TILE_SIZE)
	reset_camera()
#endregion

#region Camera stuffs
func move_camera(x: float, y: float) -> void:
	_camera_offset.x += x
	_camera_offset.y += y

func anim_camera_start(x: float, y: float, time: float) -> void:
	_camera_anim_elapsed_time = 0.0
	_camera_anim_time = time
	_camera_anim_pos = Vector2(x, y)
	_need_to_move_camera = true

func anim_camera_update(delta: float) -> void:
	var time = min(_camera_anim_elapsed_time / _camera_anim_time, 1.0)
	_camera_offset = _camera_anim_pos * time
	_camera_anim_elapsed_time += delta

func reset_camera() -> void:
	_camera_anim_pos = Vector2.ZERO
	_camera_anim_time = -1.0
	_need_to_move_camera = false
	_camera_offset = Vector2.ZERO
#endregion

#region Getters and Setters
func is_tile_air(foreground: TileMapLayer, pos: Vector2i) -> bool:
	return foreground.get_cell_source_id(pos) == -1

func get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func get_foreground() -> TileMapLayer:
	var children = get_tree().get_first_node_in_group("Geometry").get_children()
	var foreground : TileMapLayer = children.filter(func(child): return child.name.begins_with("Fore"))[0]
	return foreground

func get_map_position(foreground: TileMapLayer, relative_to_player: Vector2i = Vector2i.ZERO) -> Vector2i:
	var map_pos : Vector2i = foreground.local_to_map(foreground.to_local( global_position )) + relative_to_player
	return map_pos

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func unset_jump_input() -> void:
	_jumpBufferTimer = 0

func set_attack_input() -> void:
	_attackBufferTimer = attackBufferTime

func unset_attack_input() -> void:
	_attackBufferTimer = 0

func set_shoot_input() -> void:
	_shootBufferTimer = shootBufferTime

func unset_shoot_input() -> void:
	_shootBufferTimer = 0

func reset_all_inputs() -> void:
	_moveInput = 0
	_vertMoveInput = 0
	_crouchInput = 0
	_climbInput = 0
	unset_jump_input()
	unset_attack_input()
	unset_shoot_input()

func set_anim_move_state(moveState: MoveState, moving: bool) -> void:
	match moveState:
		MoveState.Standing:
			animator.set(IDLESTATEPARAM, "Stand")
			animator.set(MOVESTATEPARAM, "Stand")
			animator.set(FIRESTATEPARAM, "Stand")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Crouching:
			animator.set(IDLESTATEPARAM, "Crouch")
			animator.set(MOVESTATEPARAM, "Crouch")
			animator.set(FIRESTATEPARAM, "Crouch")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Climbing:
			animator.set(IDLESTATEPARAM, "Climb")
			animator.set(MOVESTATEPARAM, "Climb")
			animator.set(FIRESTATEPARAM, "Jump")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Jumping:
			animator.set(FIRESTATEPARAM, "Jump")
			anim_jumping = true
			anim_moving = true
			anim_hurt = false
		MoveState.Knockback:
			anim_hurt = true

#endregion
