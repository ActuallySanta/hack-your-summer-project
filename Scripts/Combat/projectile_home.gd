class_name ProjectileHome

static func current_room() -> Node:
	var game := GameManager.instance
	if game and is_instance_valid(game.map) and game.map.is_inside_tree():
		return game.map
	return null

static func adopt(projectile: Node2D) -> void:
	_adopt_now.call_deferred(projectile)

static func _adopt_now(projectile: Node2D) -> void:
	if not is_instance_valid(projectile) or not projectile.is_inside_tree():
		return
	var room := current_room()
	if room == null or room == projectile:
		return
	if room.is_ancestor_of(projectile):
		return
	projectile.reparent(room, true)
