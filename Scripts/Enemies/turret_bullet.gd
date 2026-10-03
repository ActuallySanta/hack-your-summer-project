class_name TurretBullet extends Bullet

@export var is_dangerous : bool

const WEAK := preload("res://Sprites/Bullets/TurretBullet.png") # THY END IS NOW
const DANGER := preload("res://Sprites/Bullets/TurretBulletDanger.png")

func set_mode() -> void:
	if Difficulty.current_difficulty == Difficulty.DifficultyID.BullShit:
		_make_dangerous()
		return
	if is_dangerous: _make_dangerous()

func _make_dangerous() -> void:
	do_wall_collisions = false
	move_speed = 300
	$Sprite2D.texture = DANGER

func post_init_operations() -> void:
	pass
