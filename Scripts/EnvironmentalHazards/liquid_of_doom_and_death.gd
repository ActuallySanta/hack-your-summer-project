extends TileMapLayer

@onready var areaCollider : CollisionShape2D = $Area2D/CollisionShape2D

var is_player_in_doom : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_player_in_doom = false
	var used_rect := get_used_rect()
	var cell_size := tile_set.tile_size
 
	# 2. Calculate pixel position and size
	var pixel_pos: Vector2 = used_rect.position * cell_size
	pixel_pos.y += 16
	var pixel_size: Vector2 = used_rect.size * cell_size
	
	# Center the rectangle shape properly
	areaCollider.shape.size = pixel_size
	areaCollider.position = Vector2.ZERO
	var map_center: Vector2 = pixel_pos + (pixel_size / 2.0)
	$Area2D.global_position = to_global(map_center)
	areaCollider.set_deferred("disabled", false)

func _process(delta: float) -> void:
	if not is_player_in_doom:
		return
	
	print("Player is in")

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	is_player_in_doom = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	is_player_in_doom = false
