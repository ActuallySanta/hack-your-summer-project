class_name PlayerBullet
extends Hitbox

@export var speed := 400.0
@export var lifetime := 3.0

var direction : Vector2
var duration_timer : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	duration_timer = lifetime

func _physics_process(delta: float) -> void:
	position += speed * direction * delta
	duration_timer -= delta
	if duration_timer <= 0:
		queue_free()

func _on_hit(_hitbox: Hitbox, _target: Hurtbox) -> void:
	queue_free()

func _on_environment_hit(_target: Node2D) -> void:
	#perhaps have different hit fx with combat & non-combat hits
	queue_free()
