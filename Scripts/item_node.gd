extends Area2D

@export var height: float = 1
@export var hover_cycle_seconds: float = 1
@export var texture: Resource
@export_enum("Jetpack") var item: String
@onready var sprite: Sprite2D = $Icon

var _game_time: float = 0.0
var _occilation_amount: float = 0.0
var _start_position := Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.texture = texture
	_start_position = global_position
	_occilation_amount = 2 * PI / hover_cycle_seconds

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_game_time += delta
	var eval = height * sin(_game_time * _occilation_amount)
	sprite.global_position.y = _start_position.y + eval

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		ItemCollectionTooling.collect_item(item)
		queue_free()
