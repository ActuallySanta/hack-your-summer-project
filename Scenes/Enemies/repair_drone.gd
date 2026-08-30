extends RigidBody2D

#region What the drone is doing

enum Mode {
	## Nothing to repair. Drifting on a diagonal at [member speed], bouncing off
	## walls, rescanning every [member idle_rescan_interval] seconds.
	Idle,
	## Flying the route in [member _path] toward [member _target].
	Seeking,
	## Parked at the target, counting down its repair timer.
	Repairing,
	## Shot with a stun bullet. Thrusters off, gravity on, falls to the floor.
	Stunned,
}

## Headings [member start_direction] can name, and the one an idle drone falls back to
## when it has no speed to read a heading off.
const IDLE_DIRECTIONS := {
	"UR": Vector2(1, -1),
	"UL": Vector2(-1, -1),
	"DR": Vector2(1, 1),
	"DL": Vector2(-1, 1),
}

## The group every [RepairNode] puts itself in.
const REPAIRABLE_GROUP := &"Repairable"

## Below this the drone counts as stopped: too slow to read a heading off, and too
## slow for the sprite to be worth turning.
const _STOPPED_SPEED := 4.0

#endregion

#region Tuning

@export_enum("UR", "UL", "DR", "DL") var start_direction : String = "UR"

## Drift speed with nothing left to repair. Idling is the slower, more visible state;
## the speed it travels to a job at belongs to the [Navigator] child, along with
## everything else about how it flies there.
@export var speed : float = 100.0

## How close to a waypoint counts as having reached it.
@export var waypoint_cutoff : float = 32.0

## Seconds spent on the floor after a stun bullet.
@export var stun_time : float = 5.0

## Seconds between scans while idle, so a drone that ran out of work picks up a
## machine that breaks later. 0 to idle forever once the room is repaired.
@export var idle_rescan_interval : float = 2.0

#endregion

@onready var navigator : RigidBodyNavigator = $Navigator
@onready var sprite : RepairerSpriteAnimator = $Flasher/RepairerSpriteAnimator
@onready var flasher : Flasher = $Flasher
@onready var hitbox : CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health_component : RoboHealth = $RoboHealth

var _mode : Mode = Mode.Idle
var _target : RepairNode
## Remaining waypoints, the target last. Emptied as each one is reached.
var _path : Array[Vector2]
var _stun_left : float = 0.0
var _rescan_left : float = 0.0

func _ready() -> void:
	# Bounce and friction are switched between flying and stunned, so this body needs
	# its own copy of the material rather than the shared resource every drone loads.
	physics_material_override = physics_material_override.duplicate()
	health_component.on_death_event.connect(on_death)
	_enable_thrusters()
	restart_sequence()

func on_death() -> void:
	_release_target()
	queue_free()

#region The sequence

## Drops whatever the drone was doing and starts again from the scan: pick the closest
## repair node, ask [RoomPathfinder] how to get there, and fly it. Idles when the scan
## comes back empty.
func restart_sequence() -> void:
	_release_target()
	_path.clear()
	_target = _find_closest_repair_node()
	if _target == null:
		_enter_idle()
		return
	_path = RoomPathfinder.find_path(global_position, _target.global_position)
	_mode = Mode.Seeking

func _process(delta: float) -> void:
	match _mode:
		Mode.Stunned:
			_stun_left -= delta
			if _stun_left <= 0.0:
				_enable_thrusters()
				restart_sequence()
		Mode.Seeking:
			_advance_path()
		Mode.Repairing:
			# The node frees itself the moment it is fixed, and another drone may have
			# been the one to finish it.
			if not is_instance_valid(_target):
				restart_sequence()
		Mode.Idle:
			if idle_rescan_interval <= 0.0:
				return
			_rescan_left -= delta
			if _rescan_left <= 0.0:
				restart_sequence()

func _advance_path() -> void:
	if not is_instance_valid(_target):
		restart_sequence()
		return
	if _path.is_empty():
		_begin_repairs()
		return
	if global_position.distance_to(_destination()) <= waypoint_cutoff:
		_path.remove_at(0)
		if _path.is_empty():
			_begin_repairs()

func _destination() -> Vector2:
	if _path.size() <= 1 and is_instance_valid(_target):
		return _target.global_position
	return _path[0]

func _begin_repairs() -> void:
	_mode = Mode.Repairing
	_target.start_repairs()
	if not _target.on_repair_end.is_connected(_on_repairs_finished):
		_target.on_repair_end.connect(_on_repairs_finished)

func _on_repairs_finished() -> void:
	restart_sequence()

func _release_target() -> void:
	if not is_instance_valid(_target):
		_target = null
		return
	if _target.on_repair_end.is_connected(_on_repairs_finished):
		_target.on_repair_end.disconnect(_on_repairs_finished)
	if _mode == Mode.Repairing:
		_target.stop_repairing()
	_target = null

func _find_closest_repair_node() -> RepairNode:
	var closest : RepairNode = null
	var closest_distance : float = INF
	for node in get_tree().get_nodes_in_group(REPAIRABLE_GROUP):
		var repairable := node as RepairNode
		if repairable == null or repairable.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(repairable.global_position)
		if distance < closest_distance:
			closest = repairable
			closest_distance = distance
	return closest

#endregion

#region Movement

## Velocity is written here rather than pushed with forces, because every mode wants a
## speed of its own and this is the one place that sees what the engine did with the
## last one: [param state] arrives holding the velocity that came out of this tick's
## collisions, so a bounce is already in it before anything below reads it.
##
## Pursuit is the [Navigator] child's, which is handed that post-bounce velocity and
## answers with the next one. Idle drift is not -- it is a fixed diagonal, and there
## is nothing for a navigator to steer toward.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	match _mode:
		Mode.Stunned:
			return # Falling: gravity and the floor own the velocity
		Mode.Idle:
			state.linear_velocity = _snap_to_diagonal(state.linear_velocity) * speed
		Mode.Seeking:
			state.linear_velocity = navigator.steer_towards(global_position, state.linear_velocity, _destination())
		Mode.Repairing:
			state.linear_velocity = navigator.brake(global_position, state.linear_velocity)
	_face(state.linear_velocity)

## The diagonal [param velocity] is already closest to, so a bounce off a wall turns
## the drone onto the neighbouring diagonal and nothing else. An axis with no speed
## worth reading keeps the sign it had, falling back to [member start_direction].
func _snap_to_diagonal(velocity: Vector2) -> Vector2:
	var fallback := _start_heading()
	var epsilon := maxf(speed, 1.0) * 0.001

	var x := signf(velocity.x) if absf(velocity.x) > epsilon else fallback.x
	var y := signf(velocity.y) if absf(velocity.y) > epsilon else fallback.y

	return Vector2(x, y).normalized()

func _start_heading() -> Vector2:
	return IDLE_DIRECTIONS.get(start_direction, Vector2(1, -1))

func _face(velocity: Vector2) -> void:
	if velocity.length() > _STOPPED_SPEED:
		sprite.get_closest_dir(velocity.normalized())

#endregion

#region Modes

func _enter_idle() -> void:
	_mode = Mode.Idle
	_rescan_left = idle_rescan_interval
	# Coming to a stop and then finding nothing to do would leave the drone parked
	# with no heading to snap, so give it its starting one back.
	if linear_velocity.length() <= _STOPPED_SPEED:
		linear_velocity = _start_heading().normalized() * speed

func _enable_thrusters() -> void:
	hitbox.set_deferred("disabled", false)
	physics_material_override.bounce = 1.0
	physics_material_override.friction = 0.0
	gravity_scale = 0.0
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0

## Cuts the thrusters: the drone stops hurting anything, falls, and lands with a much
## deader bounce than it flies with.
func disable_thrusters() -> void:
	_release_target()
	_path.clear()
	_mode = Mode.Stunned
	_stun_left = stun_time
	hitbox.set_deferred("disabled", true)
	gravity_scale = 1.0
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 1.0
	linear_damp_mode = DAMP_MODE_COMBINE
	linear_damp = 0.0
	sprite.show_deactivated()

#endregion

#region Being hit

## Every hit the drone takes arrives here, through its [Hurtbox], and this is the only
## place that decides what one means.
##
## It used to share that job with a bare [Area2D] watching the bullets collision layer,
## which stunned on anything it saw and asked no questions. Every projectile in the game
## sits on that layer, so the drone was stunned by enemy fire as readily as by the stun
## gun -- and a fallen cyborg it had just repaired into a ranged enemy would then shoot
## it faster than [member stun_time] could run out, pinning it on the floor for good.
func _on_hit(_hit_info: HitInfo, source: Hitbox) -> void:
	if source.has_method("get_damage_type"):
		var dmg_type : StringName = source.get_damage_type()
		if dmg_type == "stun_bullet":
			disable_thrusters()
			return
	flasher.flash()

#endregion
