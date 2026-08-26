class_name PlayerBullet
extends Hitbox

@export var plasma_damage := 1
@export var speed := 400.0
@export var lifetime := 3.0

var mode : StringName
var direction : Vector2
var duration_timer : float

## Wherever it was spawned, a bullet belongs inside the room it was fired in -- see
## [ProjectileHome]. This one used to be parented to the viewport root, so it went on
## flying through whatever room came next.
func _ready() -> void:
	super._ready()
	ProjectileHome.adopt(self)
	duration_timer = lifetime
	if mode == "plasma":
		damage = plasma_damage

func _physics_process(delta: float) -> void:
	# Global, so travel is unaffected by any transform on the room the bullet was
	# adopted into.
	global_position += speed * direction * delta
	duration_timer -= delta
	if duration_timer <= 0:
		queue_free()

func _on_hit(_hitbox: Hitbox, _target: Hurtbox) -> void:
	queue_free()

func set_mode(mode_name: StringName) -> void:
	mode = mode_name
	if mode_name == "stun":
		$StunBullet.visible = true
	elif mode_name == "plasma":
		$PlasmaBullet.visible = true

func get_damage_type() -> StringName:
	match mode:
		"stun":
			return "stun_bullet"
		"plasma":
			return "plasma_bullet"
	
	return "NULL"

func _on_environment_hit(target: Node2D) -> void:
	if mode != "plasma":
		queue_free()
	if "BreakAbles" in target.name:
		var tile_target := target as TileMapLayer
		if tile_target == null:
			return
		
		var foreground : TileMapLayer = get_tree().get_first_node_in_group("Geometry")
		var coordinates = tile_target.local_to_map(tile_target.to_local( global_position ) )
		# A shot that cannot break the tile still uncovers it: the gun doubles as
		# a probe for what is buried in a wall, which the wrench deliberately
		# does not.
		tile_target.destroy_tile( coordinates, get_damage_type(), foreground, Callable(), true )
		return
	
	
