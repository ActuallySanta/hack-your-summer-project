extends Door

@onready var sprite : AnimatedSprite2D = $Door1
@onready var collider : StaticBody2D = $StaticBody2D

func should_be_opened_check() -> bool:
	return GameManager.is_station_powered()

func animate_open() -> void:
	collider.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.play("Opening")

func immediate_open() -> void:
	collider.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.play("IdleOpen")
