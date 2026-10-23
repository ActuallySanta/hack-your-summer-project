class_name Miner extends Node2D

@export var ignore_player_collider : bool = false
@export var spawn_time_in_seconds : float = 1.0
@export var max_mines : int = 4

@onready var visuals := $VisualManager
@onready var player_collider := $PlayerCollider
@onready var health_component := $RoboHealth
@onready var mine_spawner := $Spawner

var _path : Path
var _timer : SmartTimer
var _player : Node2D
var _min_time : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_parent() is Path: _path = get_parent() as Path
	_min_time = float( DifficultyManager.pick_from_difficulty( [ spawn_time_in_seconds / 2, 0 ] ) )
	max_mines = int(DifficultyManager.scale_with_mode( max_mines, 2.3 ))
	
	health_component.on_low_health_entry.connect( visuals.switch_to_damaged )
	if ignore_player_collider:
		player_collider.queue_free()
	else:
		player_collider.body_entered.connect( area_entered );
		player_collider.body_exited.connect( area_exited );
	
	_timer = SmartTimer.new( spawn_time_in_seconds, spawn_mine_task  )

func spawn_mine_task() -> void:
	if _path == null: return
	var old_speed := _path.node_speed
	_path.node_speed = 0
	_timer.pause()
	
	await get_tree().create_timer( 0.3 ).timeout
	
	mine_spawner.spawn_object(1)
	
	await get_tree().create_timer( 1.0 ).timeout
	
	_path.node_speed = old_speed
	var new_time = randf_range(_min_time, spawn_time_in_seconds)
	print( new_time )
	_timer.start(new_time)



func _on_hit(hit_info: HitInfo, _source: Hitbox) -> void:
	if hit_info.damage > 0: $VisualManager/Flasher.flash()

func _process(delta: float) -> void:
	if _player: visuals.move_eye( _player.global_position )
	_timer.increment(delta)

func area_entered(target: Node) -> void:
	if not target is Player: return
	_player = target
	
func area_exited(target: Node) -> void:
	if not target is Player: return
	_player = target
