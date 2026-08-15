class_name PlayerMeleeSwing
extends Node2D

## The kind of breakable tile this attack is allowed to break.
## Matches a key of BreakAbles' NAME_TO_ATLAS.
const DAMAGE_TYPE : StringName = &"wrench"

@export var lifetime := 0.5

@onready var hitbox : Hitbox = $Hitbox

var _lifetime_timer : float

func _ready() -> void:
	_lifetime_timer = lifetime
	$AnimatedSprite2D.play("default")

func _physics_process(delta: float) -> void:
	_lifetime_timer -= delta
	if _lifetime_timer <= 0:
		queue_free()

## A swing is wide enough to cover several tiles at once, so it breaks every
## breakable cell under the hitbox rather than just the one under its centre.
func _on_environment_hit(target: Node2D) -> void:
	var tiles := target as TileMapLayer
	if tiles == null or not tiles.has_method("destroy_tile"):
		return

	var foreground : TileMapLayer = get_tree().get_first_node_in_group("Geometry")
	for coords in _covered_cells(tiles):
		tiles.destroy_tile(coords, DAMAGE_TYPE, foreground)

## The cells of [param tiles] that the hitbox's shapes overlap.
func _covered_cells(tiles: TileMapLayer) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	for child in hitbox.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue

		# Done in the layer's own space, where its cells stay axis-aligned even
		# though the breakable layers are all scaled up.
		var to_layer : Transform2D = tiles.global_transform.affine_inverse() * shape_node.global_transform
		var bounds : Rect2 = to_layer * shape_node.shape.get_rect()
		var first := tiles.local_to_map(bounds.position)
		var last := tiles.local_to_map(bounds.end)

		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var coords := Vector2i(x, y)
				if cells.has(coords) or not tiles.does_tile_exist(coords):
					continue
				# local_to_map rounds outwards, so cells the bounds only reach
				# the edge of are dropped here.
				if bounds.intersects(tiles.cell_rect(coords)):
					cells.append(coords)
	return cells
