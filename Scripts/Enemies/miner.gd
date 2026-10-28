class_name Miner extends Node2D

@export var ignore_player_collider : bool = false
@export var spawn_time_in_seconds : float = 1.0
@export var max_mines : int = 4

@onready var visuals := $VisualManager
@onready var player_collider := $PlayerCollider
@onready var health_component := $RoboHealth
@onready var mine_spawner := $Spawner
@onready var repair_node : RepairNode = $RepairNode

@onready var dropSFX : AudioStreamPlayer2D = $AudioSources/DropSFX
@onready var ouchSFX : AudioStreamPlayer2D = $AudioSources/OwieSFX

var _path : Path
var _timer : SmartTimer
var _player : Node2D
var _min_time : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_parent() is Path: _path = get_parent() as Path
	_min_time = float( Difficulty.pick_from_difficulty( [ spawn_time_in_seconds / 2, 0 ] ) )
	max_mines = int(Difficulty.scale_with_mode( max_mines, 2.3 ))
	
	if Difficulty.is_at_least(Difficulty.BULLSHIT):
		health_component.on_hit_event.connect( enable_repairing )
		modulate.a = 0.02
	elif Difficulty.is_higher_than( Difficulty.EASY ):
		health_component.on_low_health_entry.connect( enable_repairing )
		
	repair_node.on_repair_start.connect( on_repair_start )
	repair_node.on_repair_failure.connect( on_repair_fail )
	repair_node.on_repair_end.connect( on_repair_success )
		
	
	health_component.on_low_health_entry.connect( visuals.switch_to_damaged )
	if ignore_player_collider:
		player_collider.queue_free()
	else:
		player_collider.body_entered.connect( area_entered );
		player_collider.body_exited.connect( area_exited );
	
	_timer = SmartTimer.new( spawn_time_in_seconds, spawn_mine_task  )

#region repairing

func enable_repairing() -> void:
	repair_node.can_repair = true

func on_repair_start() -> void:
	print("start repairs...")

func on_repair_fail() -> void:
	print("failed")

func on_repair_success() -> void:
	health_component.max_out()
	visuals.switch_to_healed()
	repair_node.can_repair = false
	
#endregion

func spawn_mine_task() -> void:
	if _path == null: return
	var old_speed := _path.node_speed
	_path.node_speed = 0
	_timer.pause()
	
	await get_tree().create_timer( 0.3 ).timeout
	
	mine_spawner.spawn_object(1)
	dropSFX.play()
	
	await get_tree().create_timer( 1.0 ).timeout
	
	_path.node_speed = old_speed
	var new_time = randf_range(_min_time, spawn_time_in_seconds)
	_timer.start( new_time )

func _on_hit(hit_info: HitInfo, _source: Hitbox) -> void:
	if hit_info.damage <= 0: return 
	$VisualManager/Flasher.flash()
	ouchSFX.play()

func _process(delta: float) -> void:
	if _player: visuals.move_eye( _player.global_position )
	_timer.increment(delta)

func area_entered(target: Node) -> void:
	if not target is Player: return
	_player = target
	
func area_exited(target: Node) -> void:
	if not target is Player: return
	_player = target
