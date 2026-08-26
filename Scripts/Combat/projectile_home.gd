## Where a projectile belongs in the scene tree.
##
## The answer is: inside the room it was fired in. A room is loaded and freed as one
## node, so a projectile parented under it is cleaned up with it and nothing has to
## remember it exists.
##
## Every kind of projectile in the game had picked a different answer -- the player's
## bullets went to [code]get_tree().root[/code], the ranged enemies' to
## [code]get_tree().current_scene[/code], the drone's to whatever node it was told --
## and the first two are both [i]outside[/i] the room, so those bullets outlived the
## room they were fired in and went on flying through the next one.
##
## Rather than fixing each spawn site, the projectiles adopt themselves: [Bullet] and
## [PlayerBullet] call [method adopt] as they enter the tree, so a spawn site can go
## on adding them wherever it likes and they still end up somewhere sane. A new kind
## of projectile only has to make the same one call.
class_name ProjectileHome

## The node the current room was loaded into, or null when no room is loaded -- the
## menu, mid-transition, or a test scene with no [GameManager].
static func current_room() -> Node:
	var game := GameManager.instance
	if game and is_instance_valid(game.map) and game.map.is_inside_tree():
		return game.map
	return null

## Moves [param projectile] into the current room, unless it is already somewhere
## inside one. Its global transform is kept, so this never changes where it appears.
##
## Deliberately a no-op when there is no room: the test scenes have no [GameManager]
## and their projectiles are fine where they are.
##
## Deferred, because this is called from [method Node._ready], which can run inside
## another node's [code]add_child[/code] -- and a parent is not allowed to gain or
## lose children while it is in the middle of that.
static func adopt(projectile: Node2D) -> void:
	_adopt_now.call_deferred(projectile)

static func _adopt_now(projectile: Node2D) -> void:
	if not is_instance_valid(projectile) or not projectile.is_inside_tree():
		return
	var room := current_room()
	if room == null or room == projectile:
		return
	# Already under the room -- possibly as a child of an enemy that is itself in the
	# room, which some spawners do on purpose. Leave those alone.
	if room.is_ancestor_of(projectile):
		return
	projectile.reparent(room, true)
