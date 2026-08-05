class_name PlayerBullet
extends Hitbox

@export var speed := 400.0
@export var lifetime := 3.0

var mode : StringName
var direction : Vector2
var duration_timer : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	duration_timer = lifetime

func _physics_process(delta: float) -> void:
	position += speed * direction * delta
	duration_timer -= delta
	if duration_timer <= 0:
		queue_free()

func _on_hit(_hitbox: Hitbox, _target: Hurtbox) -> void:
	if mode != "plasma":
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
		tile_target.destroy_tile( coordinates, get_damage_type(), foreground )
		return
	
	
