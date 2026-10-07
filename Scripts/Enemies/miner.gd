extends Node2D

@export var ignore_player_collider : bool = false

@onready var visuals := $VisualManager
@onready var player_collider := $PlayerCollider
@onready var health_component := $RoboHealth

var _player : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_component.on_hit_event.connect( $VisualManager/Flasher.flash )
	health_component.on_low_health_entry.connect( visuals.switch_to_damaged )
	if ignore_player_collider:
		player_collider.queue_free()
	else:
		player_collider.body_entered.connect( area_entered );
		player_collider.body_exited.connect( area_exited );

func _process(_delta: float) -> void:
	if _player: visuals.move_eye( _player.global_position )

func area_entered(target: Node) -> void:
	if not target is Player: return
	_player = target
	
func area_exited(target: Node) -> void:
	if not target is Player: return
	_player = target
